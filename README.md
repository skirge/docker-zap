# docker-zap

For now, this is here to help me collect, organize, and articulate my [goal](https://wiki.mozilla.org/QA/Execution/Web_Testing/Goals/2016/Q2#Stephen) and progress on an attempt to integrate a Dockerized [OWASP-ZAP] (https://www.owasp.org/index.php/OWASP_Zed_Attack_Proxy_Project) command-line client, into [Jenkins] (https://webqa-ci.mozilla.com/).

I've blogged about the above, here: https://blog.mozilla.org/webqa/2016/06/28/dockerized-owasp-zap-security-scanning-in-jenkins-part-two/

There's also an implicit goal of not unnecessarily duplicating others' work, where possible.

I'm using the following, currently:
* https://github.com/zaproxy/zaproxy/wiki/Docker
* https://github.com/Grunny/zap-cli

Feedback and pull requests are most welcome :-)

# How to use

Create output directories (optional):

```
mkdir -p /tmp/report
chmod a+w /tmp/report
mkdir /tmp/session
chmod a+w /tmp/session
```

Start proxy:

```
./run-docker.sh -m proxy -i owasp/zap2docker-stable -p 8090 -r /tmp/report -s /tmp/session
```

Switches `-r` and `-s` are optional, but without them you will loose session and report files after scanning.

Run your Selenium/REST/whatever integration test using proxy:

File `container_ip` contains ip of ZAP's container. You can use it or get IP using `docker inspect`.

```
java -jar my-tests.jar -Dhttp.proxyHost=`cat container_ip` -Dhttp.proxyPort=8090 
```
Start scanner:

```
./run-docker.sh -m scan http://targetip:8080 http://targetip:9090
```

Archive report files from directory given by `-r` option in Jenkins.

