set[:nimbus][:client][:location] = "/nimbus"
set[:nimbus][:client][:user] = "nimbus"
set[:nimbus][:client][:group] = "nimbus"
set[:nimbus][:client][:src_checksum] = "b7e191e475ea17df941c8da818ebd171a2a17d07b8414fceef9e1566743da8fe"
set[:nimbus][:client][:src_version] = "016"
set[:nimbus][:client][:src_name] = "nimbus-cloud-client-#{nimbus[:client][:src_version]}.tar.gz"
set[:nimbus][:client][:src_mirror] = "http://www.nimbusproject.org/downloads/#{nimbus[:client][:src_name]}"

set[:nimbus][:controls][:location] = "/opt/nimbus"
set[:nimbus][:controls][:user] = "nimbus"
set[:nimbus][:controls][:group] = "nimbus"
set[:nimbus][:controls][:src_checksum] = "02bf327d3f6c7afe3f6e29d9850a7a906a714468df224858892693e26daedcbb"
set[:nimbus][:controls][:src_version] = "2.5"
set[:nimbus][:controls][:src_name] = "nimbus-controls-#{nimbus[:controls][:src_version]}.tar.gz"
set[:nimbus][:controls][:src_mirror] = "http://www.nimbusproject.org/downloads/#{nimbus[:controls][:src_name]}"

set[:nimbus][:service][:location] = "/nimbus"
set[:nimbus][:service][:user] = "nimbus"
set[:nimbus][:service][:group] = "nimbus"
set[:nimbus][:service][:src_checksum] = "ddbb9ae1db1c71d77044396e5183482a7eec144307d8b164127d79204a0bf68d"
set[:nimbus][:service][:src_version] = "2.5"
set[:nimbus][:service][:src_name] = "nimbus-#{nimbus[:service][:src_version]}-src.tar.gz"
set[:nimbus][:service][:src_mirror] = "http://www.nimbusproject.org/downloads/#{nimbus[:service][:src_name]}"

set[:nimbus][:memory_request] = 3584
