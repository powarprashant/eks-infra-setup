resource "aws_db_instance" "cloudcart_db" {

  identifier = "cloudcart-db"

  engine = "postgres"
  engine_version = "14"

  instance_class = "db.t3.micro"

  allocated_storage = 20

  username = var.db_username
  password = var.db_password

  db_name = "cloudcart"

  skip_final_snapshot = true

}