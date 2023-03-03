# frozen_string_literal: true

module UrlList
  class Package
    attr_reader :name, :version, :source_url

    def initialize(name:, version:, source_url:)
      @name = name
      @version = version
      @source_url = source_url
    end

    def ==(other)
      name == other.name &&
        version == other.version &&
        source_url == other.source_url
    end
  end
end