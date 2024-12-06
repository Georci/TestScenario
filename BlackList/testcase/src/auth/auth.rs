use alloy::{
    dyn_abi::DynSolValue,
    network::{EthereumWallet, NetworkWallet, TransactionBuilder},
    primitives::{address, utils::parse_ether, Address, BlockHash, Bytes, FixedBytes, U256},
    providers::{
        ext::{DebugApi, TraceApi},
        fillers::{NonceFiller, NonceManager},
        Provider, ProviderBuilder, RootProvider, WalletProvider, WsConnect,
    },
    pubsub::PubSubFrontend,
    rpc::types::{
        trace::geth::{CallFrame, GethDebugTracerType, GethDebugTracingOptions, TraceResult},
        TransactionRequest,
    },
    signers::{k256::elliptic_curve::rand_core::le, local::PrivateKeySigner},
    sol,
    transports::http::reqwest::Url,
};
use anyhow::{anyhow, Result};
use chrono::Utc;
use futures_util::{stream, StreamExt};
use sqlx::{mysql::MySqlPoolOptions, MySql, Pool};
use std::{collections::HashSet, env, f32::consts::E, str::FromStr, sync::Arc};
use tokio::{
    sync::{
        broadcast::{self, Receiver, Sender},
        mpsc, Mutex,
    },
    task::JoinSet,
};

use crate::auth::{
    data::{address_exists_in_blacklist, create_blacklist_entry},
    generate_data::generate_random_reason,
};

sol!(
    #[sol(rpc)]
    RegistryProxy,
    "abi/registryProxy.json"
);

sol!(
    #[sol(rpc)]
    Registry,
    "abi/registry.json"
);
type FillProvider = alloy::providers::fillers::FillProvider<
    alloy::providers::fillers::JoinFill<
        alloy::providers::fillers::JoinFill<
            alloy::providers::Identity,
            alloy::providers::fillers::JoinFill<
                alloy::providers::fillers::GasFiller,
                alloy::providers::fillers::JoinFill<
                    alloy::providers::fillers::BlobGasFiller,
                    alloy::providers::fillers::JoinFill<
                        NonceFiller,
                        alloy::providers::fillers::ChainIdFiller,
                    >,
                >,
            >,
        >,
        alloy::providers::fillers::WalletFiller<EthereumWallet>,
    >,
    RootProvider<PubSubFrontend>,
    PubSubFrontend,
    alloy::network::Ethereum,
>;
pub struct BlackListUpdater {
    provider: Arc<FillProvider>,
    black_list: Arc<Mutex<Vec<Address>>>,
}

impl BlackListUpdater {
    pub async fn new() -> Result<Self> {
        // 创建mysql实例
        // let mysql = mysql::MySqlPool::connect(&env::var("MYSQL_URL")?).await?;
        // println!("{:?}", mysql);

        // 创建provider
        let rpc = env::var("WSSRPC")?.parse::<Url>()?;
        let ws = WsConnect::new(rpc);
        let signer: PrivateKeySigner = env::var("PK")?.parse()?;

        let wallet = EthereumWallet::from(signer);

        let provider = Arc::new(
            ProviderBuilder::new()
                .with_recommended_fillers()
                .wallet(wallet)
                .on_ws(ws)
                .await?,
        );

        Ok(Self {
            provider,
            black_list: Arc::new(Mutex::new(vec![])),
        })
    }

    pub async fn run(self: Arc<Self>) -> Result<JoinSet<()>> {
        let mut set = JoinSet::new();
        let poller = self.provider.watch_blocks().await?;
        let mut stream = poller.into_stream().flat_map(stream::iter);
        let (sender_hash, _) = broadcast::channel(1000);
        let (sender_bool, mut rece_bool) = broadcast::channel(1000);
        let sender_clone = sender_hash.clone();
        let self_clone_poll = Arc::clone(&self);

        // 轮询区块
        set.spawn(async move {
            while let Some(block_hash) = stream.next().await {
                let provider = self_clone_poll.provider.clone();
                println!("轮询区块{:?}", provider.get_block_number().await);
                sender_clone.send(block_hash).unwrap();
            }
        });

        // 检测
        let self_clone_detect = Arc::clone(&self);
        set.spawn(async move {
            let mut receiver = sender_hash.subscribe();
            let provider = self_clone_detect.provider.clone();

            while let Ok(block_hash) = receiver.recv().await {
                let trace_options = GethDebugTracingOptions {
                    tracer: Some(GethDebugTracerType::BuiltInTracer(
                        alloy::rpc::types::trace::geth::GethDebugBuiltInTracerType::CallTracer,
                    )),
                    ..Default::default()
                };
                let info = provider
                    .debug_trace_block_by_hash(block_hash.into(), trace_options)
                    .await
                    .unwrap();
                // 本次检测得到的黑名单地址
                let mut new_black_list = detect(info).unwrap();
                let db_url = env::var("MYSQL_URL").expect("MYSQL_URL must be set");
                let pool = MySqlPoolOptions::new()
                    .max_connections(5)
                    .connect(&db_url)
                    .await
                    .unwrap();
                // 黑名单加入数据库
                for address in &new_black_list {
                    // 检查数据库中是否已存在该地址
                    if let Ok(exists) =
                        address_exists_in_blacklist(&pool, &address.to_string()).await
                    {
                        if exists {
                            eprintln!(
                                "Address {} is already in the blacklist. Skipping insertion.",
                                address
                            );
                            continue; // 如果存在，则跳过插入
                        }
                    }
                    let address = address.to_string();
                    let reason = generate_random_reason();
                    let status = "active";
                    let expires_at = None;
                    let chain_type = "ETH";
                    let created_by = None;

                    let result = create_blacklist_entry(
                        &pool, &address, &reason, status, expires_at, chain_type, created_by,
                    )
                    .await;

                    if let Err(err) = result {
                        eprintln!(
                            "Failed to insert blacklist entry for address {}: {}",
                            address, err
                        );
                    }
                }
                let mut locked = self_clone_detect.black_list.lock().await;
                // 更新
                locked.append(&mut new_black_list);
                println!("locked {:?}", locked);
                if locked.len() > 2 {
                    sender_bool.send(true).unwrap();
                }
                // 将locked内容写入黑名单数据库表中
            }
        });

        // 发交易，更新auth模块的地址
        let self_clone_send = Arc::clone(&self);
        set.spawn(async move {
            while let Ok(_) = rece_bool.recv().await {
                // TODO calldata
                let proxy_addr = env::var("PROXY").unwrap().parse::<Address>().unwrap();
                let proxy = RegistryProxy::new(proxy_addr, self_clone_send.provider.clone());
                let implement = Arc::new(Registry::new(
                    env::var("IMPL").unwrap().parse::<Address>().unwrap(),
                    self_clone_send.provider.clone(),
                ));

                let black_list_clone = self.black_list.lock().await.clone();

                let tokens = DynSolValue::Tuple(
                    black_list_clone
                        .into_iter()
                        .map(|addr| DynSolValue::Address(addr))
                        .collect::<Vec<_>>(),
                );
                // let param0 = env::var("PROJECT").unwrap().parse::<Address>().unwrap(); // address project
                // let param1 = DynSolValue::Bool((true)); // bool _isFuctionAccessBlacklist
                //                                         // let param2 = env::var("FUNCSIG").unwrap().parse::<Address>().unwrap(); // bytes4 funcSig
                // let param3 = env::var("BLACKADDR").unwrap().parse::<Address>().unwrap(); // address blackAddr
                // let param4 = DynSolValue::Bool((true)); // bool isblack
                // let param5 = DynSolValue::Bool((true)); // bool useFunctionAccess

                // let tokens = DynSolValue::Tuple(vec![
                //     DynSolValue::Address(param0),
                //     param1,
                //     DynSolValue::Bytes(vec![0x1, 0x2, 0x3, 0x4]),
                //     DynSolValue::Address(param3),
                //     param4,
                //     param5,
                // ]);
                let param = tokens.abi_encode();
                let call_data = implement
                    .updataModuleInfo(
                        env::var("AUTHMOD").unwrap().parse::<Address>().unwrap(),
                        param.into(),
                    )
                    .calldata()
                    .clone();
                let call_on_data = proxy.CallOn(call_data).calldata().clone();
                let tx = TransactionRequest::default()
                    .with_to(proxy_addr) // to auth_mod 地址
                    .with_input(call_on_data) // calldata
                    .with_chain_id(self_clone_send.provider.get_chain_id().await.unwrap())
                    .with_value(U256::ZERO) // chain_id
                    .with_gas_limit(10000000)
                    .with_max_fee_per_gas(0)
                    .with_max_priority_fee_per_gas(0);
                println!("等待发送交易");
                let pending_tx = self_clone_send.provider.send_transaction(tx).await.unwrap();
                let mut locked = self_clone_send.black_list.lock().await;

                locked.clear();
            }
        });

        // todo 添加一个守护线程去判断更新交易是否成功执行

        Ok(set)
    }
}

fn detect(call_trace_vec: Vec<TraceResult>) -> Result<Vec<Address>> {
    let mut black_list = vec![];
    for tx_call_trace in call_trace_vec {
        match tx_call_trace {
            TraceResult::Success { result, tx_hash } => {
                // println!("{:?}", tx_hash);
                let calltrace = result.try_into_call_frame()?;
                let to = calltrace.from.clone();
                if is_reentrancy(calltrace) {
                    black_list.push(to);
                }
            }
            _ => {}
        }
    }
    Ok(black_list)
}

fn is_reentrancy(calltrace: CallFrame) -> bool {
    // dfs calltrace
    let mut msg_list = HashSet::<String>::new();
    return _dfs(calltrace, &mut msg_list);
}

fn _dfs(calltrace: CallFrame, msg_list: &mut HashSet<String>) -> bool {
    // 初步过滤
    if calltrace.typ.eq("STATICCALL") || calltrace.to.is_none() {
        return false;
    }

    let msg = if calltrace.input.len() >= 10 {
        calltrace.to.unwrap().to_string() + "|" + calltrace.input.to_string().split_at(10).0
    } else if calltrace.input.len() == 0 {
        calltrace.to.unwrap().to_string() + "|fallback"
    } else {
        "".to_string()
    };

    // println!("MSG:{:?}", msg);

    // 构造msg = address | selector
    // 无法插入，说明已经存在调用
    if !msg_list.insert(msg) {
        return true;
    }
    // 有子调用，继续处理
    if !calltrace.calls.is_empty() {
        for call_trace in calltrace.calls {
            if _dfs(call_trace, msg_list) {
                return true;
            }
        }
    }
    return false;
}
