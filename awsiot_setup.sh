#!/bin/sh

echo "Installing MQTT tools..."
opkg update > /dev/null
opkg install mosquitto-ssl mosquitto-client-ssl libmosquitto-ssl > /dev/null

echo "Setup AWS IoT Access..."
read -p "AWS IoT Endpoint: " serviceEndpint
read -p "Thing ID: " thingId
read -p "Path to AWS IoT certificate: " certPath
read -p "Path to AWS IoT private key: " keyPath

echo "Downloading AWS IoT Root Certificate..."
mkdir -p /etc/awsiot/
wget -q https://www.symantec.com/content/en/us/enterprise/verisign/roots/VeriSign-Class%203-Public-Primary-Certification-Authority-G5.pem -O /etc/awsiot/RootCA.pem

echo "Copying certificate and key..."
cp $certPath /etc/awsiot/$thingId-certificate.pem.crt
cp $keyPath /etc/awsiot/$thingId-private.pem.key

echo "# For debugging
log_type all

# Bridge to AWS
connection bridge-to-aws
address $serviceEndpint:8883
bridge_cafile /etc/awsiot/RootCA.pem
cleansession true
try_private false
bridge_attempt_unsubscribe false
bridge_insecure false
notifications false
bridge_certfile /etc/awsiot/$thingId-certificate.pem.crt
bridge_keyfile /etc/awsiot/$thingId-private.pem.key
remote_clientid $thingId

topic \$aws/things/$thingId/shadow/update out 1
topic \$aws/things/$thingId/shadow/update/accepted in 1

topic \$aws/things/$thingId/shadow/get out 1
topic \$aws/things/$thingId/shadow/get/accepted in 1
" > /etc/mosquitto/mosquitto.conf


/etc/init.d/mosquitto restart

echo "All Done!"
echo ""

echo "Subscribe to device shadow updates with:
        mosquitto_sub -t \\\$aws/things/$thingId/shadow/update/accepted -q 1"
echo "Update device shadow with:
        mosquitto_pub -t \\\$aws/things/$thingId/shadow/update -m '{\"state\": {\"reported\": {\"varName\": 1}}}' -q 1"
echo ""
echo "  To retrieve the device shadow"
echo "Subscribe to device shadow get topic:
    mosquitto_sub -t \\\$aws/things/$thingId/shadow/get/accepted  -q 1" 
echo "Trigger device shadow get with:
    mosquitto_pub -t \\\$aws/things/$thingId/shadow/get -m ''  -q 1"

echo "Subscribe to device shadow updates with:
    mosquitto_sub -t \\\$aws/things/$thingId/shadow/update/accepted  -q 1" > /root/aws-topics.txt
echo "Update device shadow with:
    mosquitto_pub -t \\\$aws/things/$thingId/shadow/update -m '{\"state\": {\"reported\": {\"varName\": 1}}}'  -q 1"  > /root/aws-topics.txt
echo ""  > /root/aws-topics.txt
echo "Retrieve the device shadow"  > /root/aws-topics.txt
echo "Subscribe to device shadow get topic:
    mosquitto_sub -t \\\$aws/things/$thingId/shadow/get/accepted  -q 1"  > /root/aws-topics.txt
echo "Trigger device shadow get with:
    mosquitto_pub -t \\\$aws/things/$thingId/shadow/get -m ''  -q 1"  > /root/aws-topics.txt



