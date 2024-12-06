use chrono::{DateTime, Duration, Utc};
use dotenv::dotenv;
use sqlx::{mysql::MySqlPoolOptions, FromRow, MySql, Pool};
use std::env;

#[derive(Debug, FromRow)]
pub struct BlacklistEntry {
    id: i64,
    address: String,
    reason: String,
    added_at: DateTime<Utc>,
    status: String,
    expires_at: Option<DateTime<Utc>>,
    chain_type: String,
    created_by: Option<String>,
    updated_at: DateTime<Utc>,
}

pub async fn create_blacklist_entry(
    pool: &Pool<MySql>,
    address: &str,
    reason: &str,
    status: &str,
    expires_at: Option<DateTime<Utc>>,
    chain_type: &str,
    created_by: Option<&str>,
) -> Result<(), sqlx::Error> {
    let query = r#"
        INSERT INTO blockchain_blacklist (address, reason, status, expires_at, chain_type, created_by)
        VALUES (?, ?, ?, ?, ?, ?)
    "#;

    sqlx::query(query)
        .bind(address)
        .bind(reason)
        .bind(status)
        .bind(expires_at)
        .bind(chain_type)
        .bind(created_by)
        .execute(pool)
        .await?;

    Ok(())
}

// 检查地址是否已经在黑名单中
pub async fn address_exists_in_blacklist(
    pool: &Pool<MySql>,
    address: &str,
) -> Result<bool, sqlx::Error> {
    let query = r#"
        SELECT COUNT(*) FROM blockchain_blacklist WHERE address = ?
    "#;

    let count: (i64,) = sqlx::query_as(query).bind(address).fetch_one(pool).await?;

    Ok(count.0 > 0) // 如果有记录，返回 true
}

pub async fn delete_blacklist_entry(pool: &Pool<MySql>, id: i64) -> Result<(), sqlx::Error> {
    let query = "DELETE FROM blockchain_blacklist WHERE id = ?";

    sqlx::query(query).bind(id).execute(pool).await?;

    Ok(())
}

pub async fn update_blacklist_entry(
    pool: &Pool<MySql>,
    id: i64,
    status: &str,
    expires_at: Option<DateTime<Utc>>,
) -> Result<(), sqlx::Error> {
    let query = r#"
        UPDATE blockchain_blacklist
        SET status = ?, expires_at = ?
        WHERE id = ?
    "#;

    sqlx::query(query)
        .bind(status)
        .bind(expires_at)
        .bind(id)
        .execute(pool)
        .await?;

    Ok(())
}

pub async fn get_blacklist_entry(
    pool: &Pool<MySql>,
    id: i64,
) -> Result<Option<BlacklistEntry>, sqlx::Error> {
    let query = r#"
        SELECT id, address, reason, added_at, status, expires_at, chain_type, created_by, updated_at
        FROM blockchain_blacklist WHERE id = ?
    "#;

    let entry = sqlx::query_as::<_, BlacklistEntry>(query)
        .bind(id)
        .fetch_optional(pool)
        .await?;

    Ok(entry)
}

pub async fn list_blacklist(pool: &Pool<MySql>) -> Result<Vec<BlacklistEntry>, sqlx::Error> {
    let query = r#"
        SELECT id, address, reason, added_at, status, expires_at, chain_type, created_by, updated_at
        FROM blockchain_blacklist
    "#;

    let entries = sqlx::query_as::<_, BlacklistEntry>(query)
        .fetch_all(pool)
        .await?;

    Ok(entries)
}

// 示例插入函数
async fn insert_blacklist_entries(pool: &Pool<MySql>, addresses: Vec<String>) {
    for address in addresses {
        // 检查数据库中是否已存在该地址
        if let Ok(exists) = address_exists_in_blacklist(&pool, &address).await {
            if exists {
                eprintln!(
                    "Address {} is already in the blacklist. Skipping insertion.",
                    address
                );
                continue; // 如果存在，则跳过插入
            }
        }

        let reason = generate_random_reason();
        let status = "active";
        // 计算 expires_at 为当前时间后30天
        let expires_at = Some(Utc::now() + Duration::days(30));
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
}

// 假设有一个生成随机理由的函数
fn generate_random_reason() -> String {
    // 实现您的逻辑
    "Violation of terms".to_string()
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL")?;
    let pool = MySqlPoolOptions::new().connect(&database_url).await?;

    // 示例地址列表
    let addresses = vec!["0x123...".to_string(), "0x456...".to_string()];

    insert_blacklist_entries(&pool, addresses).await;

    Ok(())
}
