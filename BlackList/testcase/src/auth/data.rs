use dotenv::dotenv;
use sqlx::{mysql::MySqlPoolOptions, prelude::FromRow, MySql, Pool};
use std::env;

#[derive(Debug, FromRow)]
pub struct BlacklistEntry {
    id: i64,
    address: String,
    reason: String,
    added_at: String,
    status: String,
    expires_at: Option<String>,
    chain_type: String,
    created_by: Option<String>,
    updated_at: String,
}

pub async fn create_blacklist_entry(
    pool: &Pool<MySql>,
    address: &str,
    reason: &str,
    status: &str,
    expires_at: Option<&str>,
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
    expires_at: Option<&str>,
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
