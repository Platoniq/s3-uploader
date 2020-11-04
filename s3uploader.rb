require 'sinatra'
require 'aws-sdk'

enable :sessions
set :session_secret, ENV["SESSION_SECRET"] || SecureRandom.hex(64)

S3_BUCKET_NAMES = ENV['S3_BUCKET_NAME'].split(",")
S3_ENDPOINT = ENV['S3_ENDPOINT']
S3_REGION = ENV['S3_REGION'] || 'eu-west-1'

s3 = Aws::S3::Client.new(region: S3_REGION, endpoint: S3_ENDPOINT, force_path_style: true, ssl_verify_peer: false)
signer = Aws::S3::Presigner.new(client: s3)

get "/" do
  @buckets = S3_BUCKET_NAMES
  save_current_bucket
  if is_s3_connection_working(s3)
    haml :index
  else
    haml :error
  end
end

get "/versioning" do
  versioning_status(s3, current_bucket)
end

get '/load/:marker/?' do |marker|
  marker = decode(marker)
  @objects = get_reloaded_objects(s3, marker)
  haml :files
end

get '/load/:marker/:prefix' do |marker, prefix|
  marker = decode(marker)
  prefix = decode(prefix)
  @objects = get_reloaded_objects(s3, marker, prefix)
  haml :files
end

post "/upload" do
  #TODO Forward to error message if upload failed
  key = params['file'][:filename]
  s3.put_object({bucket: current_bucket, key: key, body: params['file'][:tempfile].read})
  redirect to('/')
end

get "/:id/download" do |id|
  key = decode(id)
  url = signer.presigned_url(:get_object, bucket: current_bucket, key: key,
                             expires_in: 30, response_content_disposition: 'attachment') 
  redirect to(url)
end

get "/:id/download/:version" do |id, version|
  key = decode(id)
  url = signer.presigned_url(:get_object, bucket: current_bucket, key: key, version_id: version,
                             expires_in: 30, response_content_disposition: 'attachment') 
  redirect to(url)
end

get "/:id/versions" do |id|
  key = decode(id)
  obj = Aws::S3::Object.new( bucket_name: current_bucket, key: key)
  @public_url = obj.public_url
  @objects = []
  begin
    response = s3.list_object_versions(bucket: current_bucket, prefix: key)
    response.versions.each do |o|
      @objects << {key: o.key, size: size_in_mb(o.size),
                   date: o.last_modified, version: o.version_id, id: encode(o.key)}
    end
  rescue
    @message = "No versions available"
  end
  haml :versions
end

def save_current_bucket
  session[:bucket] = current_bucket if session[:bucket] != current_bucket
end

def current_bucket
  return params[:bucket] if S3_BUCKET_NAMES.include? params[:bucket]

  return session[:bucket] if S3_BUCKET_NAMES.include? session[:bucket]
  
  S3_BUCKET_NAMES.first
end

def size_in_mb(value)
  (value / 1048576.0).round(1)
end

def encode(value)
  Base64.strict_encode64(value)
end

def decode(value)
  Base64.strict_decode64(value)
end

def versioning_status(s3, bucket)
  begin
    s3.get_bucket_versioning({bucket: bucket}).status || "Disabled"
  rescue
    "Disabled"
  end
end

def get_reloaded_objects(s3, marker, prefix = '')
  @objects = []
  response = s3.list_objects({bucket: current_bucket, max_keys: 100, prefix: prefix, marker: marker})
  response.contents.each do |o|
    @objects << {key: o.key, size: size_in_mb(o.size), date: o.last_modified, id: encode(o.key)}
  end
  return @objects
end

def is_s3_connection_working(s3)
  begin
    return s3.list_buckets.buckets.any? {|b| b[:name] == current_bucket}
  rescue
    false
  end
end