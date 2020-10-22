# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'fly interface' do
  let(:fly) do
    Fly.new(
      username: 'user',
      password: 'password',
      target: 'https://example.com'
    )
  end

  before do
    expect(fly).to receive(:system).with('fly -t finding-secrets login -u "user" -p "password" -c "https://example.com" -n main')
  end

  context '#teams' do
    it 'returns a list of teams' do
      fly.login!
      expect(fly).to receive('`')
        .with('fly -t finding-secrets teams --json')
        .and_return('[{"name":"team-1"},{"name":"team-2"}]')
      pipeline = fly.teams
      expect(pipeline).to eq %w[team-1 team-2]
    end
  end

  context '#pipelines' do
    it 'returns a list of pipelines' do
      fly.login!
      expect(fly).to receive(:system).with('fly -t finding-secrets login -u "user" -p "password" -c "https://example.com" -n team-1')
      expect(fly).to receive('`')
        .with('fly -t finding-secrets pipelines --json')
        .and_return('[{"name":"a"},{"name":"b"},{"name":"c"}]')
      pipeline = fly.pipelines(team: 'team-1')
      expect(pipeline).to eq %w[a b c]
    end
  end

  context '#jobs' do
    it 'returns a list of jobs for a pipeline' do
      fly.login!
      expect(fly).to receive('`')
        .with('fly -t finding-secrets jobs --pipeline "a" --json')
        .and_return('[{"name":"b"},{"name":"c"}]')
      pipeline = fly.jobs(pipeline: 'a')
      expect(pipeline).to eq %w[b c]
    end
  end

  context '#recent_build_id' do
    it 'returns the most recent build number for a pipeline job' do
      fly.login!
      expect(fly).to receive('`')
        .with('fly -t finding-secrets builds --job "a/b" --json')
        .and_return('[{"name":123},{"name":456, "end_time":12313123123}]')
      pipeline = fly.recent_build_id(pipeline: 'a', job: 'b')
      expect(pipeline).to eq 456
    end
  end

  context '#logs' do
    it 'returns logs for build number' do
      fly.login!
      expect(fly).to receive('`')
        .with('fly -t finding-secrets watch --job "a/b" --build "123"')
        .and_return('returns some logs')
      pipeline = fly.logs(pipeline: 'a', job: 'b', build: 123)
      expect(pipeline).to eq 'returns some logs'
    end
  end
end
