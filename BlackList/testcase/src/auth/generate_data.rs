use chrono::{DateTime, Duration, Utc};
use dotenv::dotenv;
use rand::seq::SliceRandom; // 导入 SliceRandom trait
use rand::{distributions::Alphanumeric, Rng};
use sqlx::{mysql::MySqlPoolOptions, MySql, Pool};
use std::env;

use super::data::create_blacklist_entry;

// 用于生成随机区块链地址，地址以 '0x' 开头，后面是 40 个字符
pub fn generate_random_address() -> String {
    let mut rng = rand::thread_rng();
    let random_address: String = (0..40) // 区块链地址通常是40个十六进制字符
        .map(|_| rng.sample(Alphanumeric) as char) // 随机生成字母数字字符
        .collect();
    format!("0x{}", random_address) // 以 '0x' 开头
}

pub fn generate_random_reason() -> String {
    let reasons = vec![
        "Fraudulent activity",
        "Money laundering",
        "Scam",
        "Phishing attempt",
        "Malicious behavior",
        "Suspicious transaction",
    ];
    let mut rng = rand::thread_rng();
    reasons.choose(&mut rng).unwrap().to_string() // 随机选择一个原因
}

// 插入50条黑名单数据
pub async fn insert_random_blacklist_entries(pool: &Pool<MySql>) -> Result<(), sqlx::Error> {
    for _ in 0..50 {
        let address = generate_random_address();
        let reason = generate_random_reason();
        let status = "active";
        let expires_at = Some(Utc::now());
        let chain_type = "ETH";
        let created_by = None;

        let result = create_blacklist_entry(
            &pool, &address, &reason, status, expires_at, chain_type, created_by,
        )
        .await;

        if let Err(err) = result {
            eprintln!("Failed to insert blacklist entry: {}", err);
        }
    }

    Ok(())
}

pub async fn setup_test_db() -> Pool<MySql> {
    dotenv().ok();
    let db_url = env::var("MYSQL_URL").expect("MYSQL_URL must be set");
    let pool = MySqlPoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await
        .expect("Failed to create pool");
    pool
}
