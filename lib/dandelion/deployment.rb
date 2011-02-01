require 'dandelion/git'

module Deployment
  class RemoteRevisionError < StandardError; end
  
  class Deployment
    def initialize(dir, service, exclude = nil, revision = 'HEAD')
      @service = service
      @exclude = exclude || []
      @tree = Git::Tree.new(dir, revision)
    end
    
    def local_revision
      @tree.revision
    end
    
    def remote_uri
      @service.uri
    end
    
    def write_revision
      @service.write('.revision', local_revision)
    end
  end
  
  class DiffDeployment < Deployment
    def initialize(dir, service, exclude = nil, revision = 'HEAD')
      super(dir, service, exclude, revision)
      @diff = Git::Diff.new(dir, read_revision)
    end
    
    def remote_revision
      @diff.revision
    end
    
    def deploy
      if !revisions_match? && any?
        deploy_changed
        deploy_deleted
      else
        puts "Nothing to deploy"
      end
      unless revisions_match?
        write_revision
      end
    end
    
    def deploy_changed
      @diff.changed.each do |file|
        if @exclude.include?(file)
          puts "Skipping file: #{file}"
        else
          puts "Uploading file: #{file}"
          @service.write(file, @tree.show(file))
        end
      end
    end
    
    def deploy_deleted
      @diff.deleted.each do |file|
        if @exclude.include?(file)
          puts "Skipping file: #{file}"
        else
          puts "Deleting file: #{file}"
          @service.delete(file)
        end
      end
    end
    
    def any?
      @diff.changed.any? || @diff.deleted.any?
    end
    
    def revisions_match?
      remote_revision == local_revision
    end
    
    private
    
    def read_revision
      begin
        @service.read('.revision').chomp
      rescue Net::SFTP::StatusException => e
        raise unless e.code == 2
        raise RemoteRevisionError
      end
    end
  end
  
  class FullDeployment < Deployment
    def deploy
      @tree.files.each do |file|
        unless @exclude.include?(file)
          puts "Uploading file: #{file}"
          @service.write(file, @tree.show(file))
        end
      end
      write_revision
    end
  end
end