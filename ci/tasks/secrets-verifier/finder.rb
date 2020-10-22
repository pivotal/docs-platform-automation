#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'paint'

class Fly
  def initialize(username:, password:, target:)
    @username = username
    @password = password
    @target = target
  end

  def login!(team: 'main')
    system(%(fly -t finding-secrets login -u "#{@username}" -p "#{@password}" -c "#{@target}" -n #{team}))
  end

  def teams
    output = JSON.parse(`fly -t finding-secrets teams --json`)
    output.map { |entry| entry['name'] }
  end

  def pipelines(team:)
    login!(team: team)
    output = JSON.parse(`fly -t finding-secrets pipelines --json`)
    output.map { |entry| entry['name'] }
  end

  def jobs(pipeline:)
    output = JSON.parse(`fly -t finding-secrets jobs --pipeline "#{pipeline}" --json`)
    output.map { |entry| entry['name'] }
  end

  def recent_build_id(job:, pipeline:)
    output = JSON.parse(`fly -t finding-secrets builds --job "#{pipeline}/#{job}" --json`)
    output.select { |entry| entry['end_time'] }.map { |entry| entry['name'] }.first
  end

  def logs(job:, pipeline:, build:)
    `fly -t finding-secrets watch --job "#{pipeline}/#{job}" --build "#{build}"`
  end
end

class Finder
  def initialize(fly:, files:, allowlist:, skip_jobs:)
    @fly = fly
    @files = files
    @allowlist = allowlist
    @skip_jobs = skip_jobs
  end

  def jobs_with_secrets
    found = {}
    @fly.teams.each do |team|
      @fly.pipelines(team: team).each do |pipeline|
        puts "Searching pipeline: #{pipeline}"
        @fly.jobs(pipeline: pipeline).reject do |job|
          @skip_jobs.include? ({ pipeline: pipeline, job: job })
        end.each do |job|
          print "- job #{job}"
          recent_build = @fly.recent_build_id(pipeline: pipeline, job: job)
          unless recent_build
            puts ' skipped'
            next
          end

          logs = @fly.logs(pipeline: pipeline, job: job, build: recent_build)
                     .gsub(/begin secrets-check ignore(.*?)end secrets-check ignore/m, '')

          found_secrets = secrets.select do |secret|
            logs.include?(secret)
          end

          puts ' checked'

          next if found_secrets.empty?

          found["#{pipeline}/#{job}/#{recent_build}"] = found_secrets
          found_secrets.each do |s|
            puts Paint["  * #{s}", :red]
          end
        end
      end
    end
    found
  end

  private

  def secrets
    @secrets ||= begin
      @files.map do |file|
        payload = YAML.load_file(file)
        unless payload.is_a?(Hash)
          raise "payload is unexpected format from #{file} -- expected Hash got #{payload.class}"
        end

        hash_values(payload)
      end
            .flatten
            .select { |s| s.is_a?(String) }
            .reject { |s| @allowlist.any? { |w| s.match?(w) } }
            .reject { |s| s.strip.empty? }
            .uniq
    end
  end

  def hash_values(payload)
    payload.values.map do |value|
      if value.is_a?(Hash)
        hash_values(value)
      else
        value
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  fly = Fly.new(
    username: ENV.fetch('FLY_USERNAME'),
    password: ENV.fetch('FLY_PASSWORD'),
    target: ENV.fetch('FLY_TARGET')
  )
  fly.login!

  Dir['deployments/**/*.tfvars'].each do |file|
    system("cat #{file} | yj -i -cj > #{file}.json")
  end

  files = Dir['deployments/**/env.yml', 'deployments/**/*.tfvars.json']
  puts "files: #{files.inspect}"

  if files.empty?
    raise 'no files for evaluating secrets were found -- ensure the directories are correct'
  end

  finder = Finder.new(
    skip_jobs: [{ pipeline: 'ci', job: 'check-for-secrets-in-tasks' }],
    fly: fly,
    files: files,
    allowlist: ENV.fetch('SECRET_ALLOWLIST').split("\n").map { |item| Regexp.new(item) }
  )

  unless finder.jobs_with_secrets.empty?
    puts 'Check secrets'
    exit 1
  end
end
