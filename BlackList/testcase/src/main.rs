use std::sync::Arc;

use anyhow::Result;
use auth::generate_data::{insert_random_blacklist_entries, setup_test_db};

mod auth;
/// 监控链上交易，更新黑白名单模块
#[tokio::main]
async fn main() -> Result<()> {
    dotenv::dotenv().ok();

    // let pool = setup_test_db().await;

    // // 插入50条黑名单数据
    // if let Err(e) = insert_random_blacklist_entries(&pool).await {
    //     eprintln!("Error inserting entries: {}", e);
    // }

    let updater = Arc::new(auth::auth::BlackListUpdater::new().await?);
    if let Ok(mut set) = updater.run().await {
        while let Some(res) = set.join_next().await {
            println!("res: {:?}", res);
        }
    }
    Ok(())
}
