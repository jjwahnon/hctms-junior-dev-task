#!/usr/bin/env ruby

# Script to help set up Terraform deployment
# This script generates necessary configuration and performs validation

require 'yaml'
require 'pathname'
require 'json'

class ApolloDeploymentSetup
  def initialize
    @root_dir = Pathname.new(__dir__).parent
    @terraform_dir = Pathname.new(__dir__)
  end

  def setup
    puts "🚀 Apollo Rails App - AWS Deployment Setup"
    puts "=" * 50
    puts

    # Check prerequisites
    check_prerequisites

    # Setup configuration
    setup_configuration

    # Show next steps
    show_next_steps
  end

  private

  def check_prerequisites
    puts "📋 Checking prerequisites..."
    puts

    errors = []

    # Check Terraform
    unless command_exists?('terraform')
      errors << "❌ Terraform not found. Install from https://www.terraform.io/downloads.html"
    else
      version = `terraform -v`.match(/Terraform v(\d+\.\d+)/)[1]
      puts "✅ Terraform #{version} installed"
    end

    # Check AWS CLI
    unless command_exists?('aws')
      errors << "❌ AWS CLI not found. Install from https://aws.amazon.com/cli/"
    else
      version = `aws --version`.match(/aws-cli\/(\d+\.\d+\.\d+)/)[1]
      puts "✅ AWS CLI #{version} installed"
    end

    # Check Docker
    unless command_exists?('docker')
      errors << "❌ Docker not found. Install from https://www.docker.com/"
    else
      version = `docker --version`.match(/Docker version ([\d\.]+)/)[1]
      puts "✅ Docker #{version} installed"
    end

    # Check AWS credentials
    begin
      account_id = `aws sts get-caller-identity --query Account --output text 2>/dev/null`.strip
      if account_id.empty?
        errors << "❌ AWS credentials not configured. Run 'aws configure'"
      else
        puts "✅ AWS credentials configured (Account: #{account_id})"
      end
    rescue
      errors << "❌ Cannot verify AWS credentials"
    end

    puts

    if errors.any?
      puts "🛑 Setup cannot proceed:"
      errors.each { |error| puts "   #{error}" }
      exit 1
    else
      puts "✅ All prerequisites met!"
      puts
    end
  end

  def setup_configuration
    puts "⚙️  Setting up configuration..."
    puts

    config_file = @terraform_dir.join('terraform.tfvars')

    if config_file.exist?
      puts "✅ terraform.tfvars already exists"
    else
      example_file = @terraform_dir.join('terraform.tfvars.example')
      if example_file.exist?
        FileUtils.cp(example_file, config_file)
        puts "✅ Created terraform.tfvars from example"
        puts "   ⚠️  Please edit terraform.tfvars with your values"
      end
    end

    # Check for Rails master key
    master_key_file = @root_dir.join('config/master.key')
    if master_key_file.exist?
      master_key = File.read(master_key_file).strip
      puts "✅ Found Rails master key"
    else
      puts "⚠️  Rails master key not found at config/master.key"
    end

    # Initialize Terraform
    puts
    puts "Initializing Terraform..."
    system("cd #{@terraform_dir} && terraform init")
  end

  def show_next_steps
    puts
    puts "=" * 50
    puts "✅ Setup Complete!"
    puts
    puts "📝 Next steps:"
    puts "1. Edit terraform.tfvars with your configuration"
    puts "2. Review variables.tf for available options"
    puts "3. Run: terraform plan"
    puts "4. Run: terraform apply"
    puts "5. Follow the DEPLOYMENT_GUIDE.md for Docker image setup"
    puts
    puts "📚 Documentation:"
    puts "   - DEPLOYMENT_GUIDE.md - Complete deployment instructions"
    puts "   - variables.tf - All available configuration options"
    puts
  end

  def command_exists?(command)
    system("which #{command} > /dev/null 2>&1") || 
    system("where #{command} > /dev/null 2>&1")
  end
end

ApolloDeploymentSetup.new.setup
