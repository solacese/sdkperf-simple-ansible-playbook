---
- hosts: sdkperf_consumer_nodes
  remote_user: "{{remote_user}}"

  ##################################################
  # SDKPerf Config Section
  #
  # INSTRUCTIONS:
  #  (1) Fill out the following variables
  #  (2) Run `ansible-playbook -i ../../ansible/inventory/az-sdkperf-nodes.inventory --private-key ../../keys/azure_key start-sdkperf-c-pub.yml`
  #  (3) If you do not have a monitoring solution in place for your broker, you'll need to check the nohup.out file on each of the sdkperf nodes.
  #  (4) Rename this file "start-sdkperf.yml"
  ##################################################
  vars:
    # sdkperf settings
    client_connection_count: 5 # 1 || 10 || 100 || 1000 || etc...

  ##################################################

  tasks:
    - name: Consume Test Queue 
      # shell: nohup ./sdkperf-c-x64/sdkperf_c -cip="{{ item }}":"{{ broker_port }}" -cu="{{ client_username }}"@"{{ broker_msg_vpn }}" -cp="{{ client_password }}" -cc="{{ client_connection_count }}" -sql="{{ msg_queue_prefix }}""{{groups['sdkperf_nodes'].index(inventory_hostname)}}" -stl="{{msg_queue_sub}}" </dev/null >nohup_qcon.out 2>&1 &
      shell: nohup dotnet sdkperf-cs-x86_64/net6.0/sdkperf_cs.dll -cip="{{ item }}":"{{ broker_port }}" -cu="{{ client_username }}"@"{{ broker_msg_vpn }}" -cp="{{ client_password }}" -cc="{{ client_connection_count }}" -sql="{{ msg_queue_prefix }}""{{groups['sdkperf_nodes'].index(inventory_hostname)}}" -stl="{{msg_queue_sub}}" </dev/null >nohup_qcon.out 2>&1 &
      loop: "{{ broker_urls }}"

