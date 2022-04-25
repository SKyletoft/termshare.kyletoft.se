#[macro_use]
extern crate rocket;

use rocket::{
	form::{Form, FromForm},
	serde::{Deserialize, Serialize},
};
use rocket_sync_db_pools::{database, diesel};

#[database("sqlite_logs")]
struct LogsDbConn(diesel::SqliteConnection);

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, FromForm)]
struct Upload<'r> {
	data: &'r str,
	user: &'r str,
	highlighting: Option<&'r str>,
}

#[get("/upload", data = "<form>")]
fn upload(form: Form<Upload<'_>>) -> String {
	let data = form.into_inner();
	dbg!(&data);
	String::from("Upload failed\n")
}

#[launch]
fn rocket() -> _ {
	rocket::build()
		.mount("/", routes![upload])
		.attach(LogsDbConn::fairing())
}
