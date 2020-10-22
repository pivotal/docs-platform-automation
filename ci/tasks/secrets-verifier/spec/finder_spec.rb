# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'yaml'

RSpec.describe 'When there are secrets in a latest build' do
  it 'reports an error' do
    fly = Fly.new(
      username: 'username',
      password: 'password',
      target: 'https://example.com'
    )

    fly.login!

    has_secrets = Tempfile.new
    has_secrets.write(YAML.dump(
                        'password' => 'super-secure-password',
                        'username' => 'admin',
                        'something' => false,
                        'region' => 'west-us-2',
                        'another-region' => 'us-central1-b',
                        'some-space-to-ignore' => ' '
                      ))
    has_secrets.close

    expect(fly).to receive(:teams).and_return(%w[team-1])
    expect(fly).to receive(:pipelines).with(team: 'team-1').and_return(%w[pipeline1 pipeline2])
    expect(fly).to receive(:jobs).with(pipeline: 'pipeline1')
                                 .and_return(%w[job-with-secrets job-without-secrets check-for-secrets-in-tasks])
    expect(fly).to receive(:jobs).with(pipeline: 'pipeline2')
                                 .and_return(%w[nothing])
    expect(fly).to receive(:recent_build_id).and_return(123).exactly(2).times
    expect(fly).to receive(:recent_build_id).and_return(nil)
    expect(fly).to receive(:logs)
      .with(pipeline: 'pipeline1', job: 'job-with-secrets', build: 123)
      .and_return("super-secure-password\nadmin\nwest-us-2\nus-central1-b")
    expect(fly).to receive(:logs)
      .with(pipeline: 'pipeline1', job: 'job-without-secrets', build: 123)
      .and_return("non-secret
        ### begin secrets-check ignore ###
        super-secure-password
        ### end secrets-check ignore ###
        ")

    finder = Finder.new(
      fly: fly,
      files: [has_secrets],
      allowlist: ['admin', /us/],
      skip_jobs: [{ pipeline: 'pipeline1', job: 'check-for-secrets-in-tasks' }]
    )

    expect(finder.jobs_with_secrets).to eq('pipeline1/job-with-secrets/123' => ['super-secure-password'])
  end
end
