use dialoguer::{Confirm, Input};
use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::{
	fs::{self, File},
	io,
	io::Write,
};

#[derive(Debug)]
enum Error {
	Io(io::Error),
	ProjectDirs,
	RejectedTerms,
}

impl From<io::Error> for Error {
	fn from(error: io::Error) -> Self {
		Error::Io(error)
	}
}

#[derive(Debug, Serialize, Deserialize)]
struct Config {
	confirmed: bool,
	username: String,
	secret_token: String,
	server: String,
}

fn main() -> Result<(), Error> {
	// read or create a new config file
	let config = if let Some(c) = get_config() {
		c
	} else {
		initial_setup()?
	};

	if !config.confirmed {
		println!("You must agree to terms to use the software");
		return Err(Error::RejectedTerms);
	}

	Ok(())
}

/// Get the config for this user
fn get_config() -> Option<Config> {
	let dirs = ProjectDirs::from("com", "TermShare", "TermShare CLI")?;
	let config_file_path = dirs.config_dir().join("config.toml");

	let contents = fs::read_to_string(config_file_path).ok()?;
	toml::from_str(&contents).ok()
}

/// Helper function to create a new config file based on a given config object
fn create_config_file(config: &Config) -> Result<(), Error> {
	let dirs =
		ProjectDirs::from("com", "TermShare", "TermShare CLI").ok_or(Error::ProjectDirs)?;

	let config_dir = dirs.config_dir();
	let config_file = config_dir.join("config.toml");

	fs::create_dir_all(&config_dir)?;

	let serialized = toml::to_string(config).unwrap();

	let mut file = File::create(&config_file)?;
	file.write_all(serialized.as_bytes())?;

	Ok(())
}

/// Welcome the user and prompt them with questions to create a
/// new account and user config
fn initial_setup() -> Result<Config, Error> {
	println!("Welcome to TermShare!");

	if !Confirm::new()
		.with_prompt("Do allow TermShare to store the data which you upload?")
		.interact()?
	{
		return Err(Error::RejectedTerms);
	}

	let server: String = Input::new()
		.with_prompt("Server")
		.default("server.foo.com".into())
		.interact_text()?;

	let username: String = Input::new()
		.with_prompt("Choose a username")
		.interact_text()?;

	// FIXME: send a request to server and ask for a token

	let config = Config {
		confirmed: true,
		username,
		secret_token: "todo".to_string(),
		server,
	};

	create_config_file(&config)?;

	Ok(config)
}
