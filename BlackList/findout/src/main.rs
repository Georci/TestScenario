use chrono::NaiveDateTime;
use clap::Parser;
use mysql::prelude::*;
use mysql::*;

/// Simple program to check if a blockchain address is blacklisted
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Blockchain address to check
    address: String,
}

#[derive(Debug, PartialEq, Eq, FromRow)]
struct BlacklistEntry {
    id: i64,
    address: String,
    reason: String,
    added_at: Option<NaiveDateTime>,
    status: Option<String>,
    expires_at: Option<NaiveDateTime>,
    chain_type: Option<String>,
    created_by: Option<String>,
    updated_at: Option<NaiveDateTime>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Parse command-line arguments
    let args = Args::parse();
    let address_to_check = args.address;

    // MySQL connection URL
    let url = "mysql://root:1234@172.23.216.120:3306/ChainFilterDB";

    // Establish a connection pool
    let pool = Pool::new(url)?;
    let mut conn = pool.get_conn()?;

    // Prepare and execute the query
    let query = "SELECT id, address, reason, added_at, status, expires_at, chain_type, created_by, updated_at
                 FROM blockchain_blacklist
                 WHERE address = :address
                 LIMIT 1";

    let result: Option<BlacklistEntry> = conn.exec_first(
        query,
        params! {
            "address" => address_to_check.clone(),
        },
    )?;

    // Check and display the result
    match result {
        Some(entry) => {
            println!("Address is blacklisted:");
            println!("ID: {}", entry.id);
            println!("Address: {}", entry.address);
            println!("Reason: {}", entry.reason);
            println!("Added At: {:?}", entry.added_at);
            println!(
                "Status: {}",
                entry.status.unwrap_or_else(|| "N/A".to_string())
            );
            println!("Expires At: {:?}", entry.expires_at);
            println!(
                "Chain Type: {}",
                entry.chain_type.unwrap_or_else(|| "N/A".to_string())
            );
            println!(
                "Created By: {}",
                entry.created_by.unwrap_or_else(|| "N/A".to_string())
            );
            println!("Updated At: {:?}", entry.updated_at);
        }
        None => {
            println!("Address '{}' is not blacklisted.", address_to_check.clone());
        }
    }

    Ok(())
}
