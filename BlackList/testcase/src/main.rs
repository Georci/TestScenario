use std::sync::Arc;

use anyhow::Result;
use testcase::auth::BlackListUpdater;
/// 监控链上交易，更新黑白名单模块
#[tokio::main]
async fn main() -> Result<()> {
    dotenv::dotenv().ok();
    let updater = Arc::new(BlackListUpdater::new().await?);
    if let Ok(mut set) = updater.run().await {
        while let Some(res) = set.join_next().await {
            println!("res: {:?}", res);
        }
    }
    Ok(())
}
