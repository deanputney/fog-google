require "fog/core/collection"
require "fog/google/models/storage_json/file"

module Fog
  module Storage
    class GoogleJSON
      class Files < Fog::Collection
        extend Fog::Deprecation
        deprecate :get_url, :get_https_url

        attribute :common_prefixes, :aliases => "CommonPrefixes"
        attribute :delimiter,       :aliases => "Delimiter"
        attribute :directory
        # attribute :is_truncated,    :aliases => "IsTruncated"
        attribute :page_token,      :aliases => ["pageToken", "page_token"]
        attribute :max_results,     :aliases => ["MaxKeys", "max-keys"]
        attribute :prefix,          :aliases => "Prefix"

        model Fog::Storage::GoogleJSON::File

        # TODO: Verify, probably doesn't work
        def all(options = {})
          requires :directory
          options = {
            "delimiter"   => delimiter,
            "pageToken"   => page_token,
            "maxResults"  => max_results,
            "prefix"      => prefix
          }.merge!(options)
          options = options.reject { |_key, value| value.nil? || value.to_s.empty? }
          merge_attributes(options)
          parent = directory.collection.get(
            directory.key,
            options
          )
          if parent
            # pp parent.files
            merge_attributes(parent.files.attributes)
            load(parent.files.map(&:attributes))
          end
          # result = service.list_objects(
          #   directory.key,
          #   options
          # )
          # pp result
          # if result
          #   files = result[:body]["items"]
          #   pp files
          #   merge_attributes(files.attributes)
          #   load(files.map(&:attributes))
          # end
        end

        # TODO: Verify
        alias_method :each_file_this_page, :each
        def each
          if !block_given?
            self
          else
            subset = dup.all

            subset.each_file_this_page { |f| yield f }
            while subset.is_truncated
              subset = subset.all(:marker => subset.last.key)
              subset.each_file_this_page { |f| yield f }
            end

            self
          end
        end

        def get(key, options = {}, &block)
          requires :directory
          data = service.get_object(directory.key, key, options, &block)
          file_data = {}
          data.headers.each do |key, value|
            file_data[key] = value
          end
          file_data.merge!(:body => data.body,
                           :key  => key)
          new(file_data)
        rescue Excon::Errors::NotFound
          nil
        end

        def get_https_url(key, expires)
          requires :directory
          service.get_object_https_url(directory.key, key, expires)
        end

        def head(key, options = {})
          requires :directory
          data = service.head_object(directory.key, key, options)
          file_data = data.headers.merge(:key => key)
          new(file_data)
        rescue Excon::Errors::NotFound
          nil
        end

        def new(attributes = {})
          requires :directory
          super({ :directory => directory }.merge(attributes))
        end
      end
    end
  end
end