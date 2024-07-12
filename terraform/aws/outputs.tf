output "sdkperf-node-public-ips" {
  value = ["${aws_instance.sdkperf-nodes.*.public_ip}"]
}
output "sdkperf-node-private-ips" {
  value = ["${aws_instance.sdkperf-nodes.*.private_ip}"]
}
