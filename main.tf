terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}
variable "do_token" {}
variable "do_count" {default = 4}
variable "vpc_ip_range" {default = "10.10.10.0/24"}
variable "gateway_size" {default = "s-4vcpu-8gb"}
variable "back_size" {default = "s-4vcpu-8gb"}
variable "pass" {}

data "digitalocean_ssh_key" "gateway" {
  name = "gateway"
}


# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}
# Create VPC
resource "digitalocean_vpc" "terraform-vpc" {
  name     = "terraform-vpc"
  region   = "lon1"
  ip_range = var.vpc_ip_range
}
# Create Gateway
resource "digitalocean_droplet" "gateway" {
    image = "ubuntu-20-04-x64"
    name = "gateway"
    region = "lon1"
    size = var.gateway_size
    vpc_uuid = digitalocean_vpc.terraform-vpc.id
    ssh_keys = [
      data.digitalocean_ssh_key.gateway.id
    ]
    user_data = <<EOT
#!/bin/bash
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl restart sshd

echo -e -n "${var.pass}\n${var.pass}" | passwd root
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
iptables -t nat -A POSTROUTING -s ${var.vpc_ip_range} -o eth0 -j MASQUERADE
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get install -y iptables-persistent
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
docker-compose --version
    EOT
}

# Create backend
resource "digitalocean_droplet" "backend" {
    count = var.do_count
    image = "ubuntu-20-04-x64"
    name = "backend-${count.index}"
    region = "lon1"
    size = var.back_size
    vpc_uuid = digitalocean_vpc.terraform-vpc.id
    ssh_keys = [
      data.digitalocean_ssh_key.gateway.id
    ]
    user_data = <<EOT
#!/bin/bash
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
systemctl restart sshd
echo -e -n "${var.pass}\n${var.pass}" | passwd root
sed -i '/gateway4/c\#gateway4' /etc/netplan/50-cloud-init.yaml
head -n 31 /etc/netplan/50-cloud-init.yaml > /tmp/50-cloud-init.yaml.txt
cat <<EOF >> /tmp/50-cloud-init.yaml.txt
            routes:
                - to: 0.0.0.0/0
                  via: ${digitalocean_droplet.gateway.ipv4_address_private}
EOF
tail -n +32 /etc/netplan/50-cloud-init.yaml  >> /tmp/50-cloud-init.yaml.txt
cat /tmp/50-cloud-init.yaml.txt > /etc/netplan/50-cloud-init.yaml
netplan apply -debug
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get -y update
apt-get -y install docker-ce docker-ce-cli containerd.io
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
docker-compose --version
    EOT
}

output "private_addreses" {
    value = {
    for k, v in digitalocean_droplet.backend : k => v.ipv4_address_private
  }
}
