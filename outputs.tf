// output instance public IP
output "public_ip" {
  value = "${aws_instance.urchin_node.public_ip}"
}
