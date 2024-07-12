[sdkperf_consumer_nodes]
%{ for ip in sdkperf_node_ips ~}
${ip}
%{ endfor ~}
[sdkperf_consumer_nodes:vars]
remote_user=${remote_user}