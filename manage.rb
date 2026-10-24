#!/usr/bin/env ruby
# frozen_string_literal: true
# Usage: DIGITALOCEAN_ACCESS_TOKEN=... ./manage.rb up|stop
# Optional: IMAGE, REGION (default mkc1), VM_NAME
require "net/http"
require "json"
require "uri"

TOKEN  = ENV["DIGITALOCEAN_ACCESS_TOKEN"] or abort("Set DIGITALOCEAN_ACCESS_TOKEN (DO API key)")
API    = "https://api.digitalocean.com/v2"
NAME   = ENV.fetch("VM_NAME", "domicrovm-hello")
IMAGE  = ENV.fetch("IMAGE", "ghcr.io/mufid/domicrovm:latest")
REGION = ENV.fetch("REGION", "mkc1")
TAG    = "domicrovm"

def request(method, path, body = nil)
  uri = URI("#{API}#{path}")
  req = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
  req["Authorization"] = "Bearer #{TOKEN}"
  req["Content-Type"] = "application/json"
  req.body = body.to_json if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  abort("#{method.upcase} #{path} failed: #{res.code} #{res.body}") unless res.is_a?(Net::HTTPSuccess)
  res.body.to_s.empty? ? {} : JSON.parse(res.body)
end

def all_vms
  request(:get, "/microvms?tag_name=#{TAG}&per_page=200")["microvms"] || []
end

def up
  if (vm = all_vms.find { |v| v["name"] == NAME })
    puts "MicroVM #{NAME} already exists (#{vm['id']}, #{vm['state']}); skipping"
  else
    vm = request(:post, "/microvms", {
      name: NAME, region: REGION,
      size: { cpu: 1, memory: 2048 },
      source: { oci_ref: IMAGE },
      http_port: 8080, http_protocol: "http",
      auto_pause: { idle_timeout: "5m" },
      tags: [TAG]
    })["microvm"]
    puts "Created #{vm['id']}"
  end
  60.times do
    vm = request(:get, "/microvms/#{vm['id']}")["microvm"]
    break if vm["state"] == "running"
    abort("Failed: #{vm['failure_reason']}") if vm["failure_reason"].to_s != ""
    sleep 2
  end
  host = vm.dig("urls")&.find { |u| u["default"] }&.dig("hostname")
  puts "State: #{vm['state']}"
  puts "URL: https://#{host}"
  puts "Try: curl -H \"Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN\" https://#{host}"
end

def stop
  vms = all_vms
  puts "No MicroVMs to delete" if vms.empty?
  vms.each do |v|
    request(:delete, "/microvms/#{v['id']}")
    puts "Deleted #{v['name']} (#{v['id']})"
  end
end

case ARGV[0]
when "up" then up
when "stop" then stop
else abort("Usage: #{$0} up|stop")
end
