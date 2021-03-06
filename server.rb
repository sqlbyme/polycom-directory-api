%w(sinatra data_mapper json builder).each  { |gems| require gems}
Dir[File.dirname(__FILE__) + "/models/*.rb"].each do |path|
  Dir[ path ].each { |model| require model }
end


class Server < Sinatra::Base

  # Set configurations
  set :show_exceptions, false

  # Setup data_mapper
  DataMapper::Logger.new($stdout, :info)
  DataMapper.setup(:default, ENV['DATABASE_URL'] || "mysql://root:#{ENV['DB_PWD'] || 'password'}@localhost/directory.feco.net_development")

  configure :test do
    DataMapper.setup(:default, "mysql://root:#{ENV['DB_PWD'] || 'password'}@localhost/directory.feco.net_development")
    DataMapper.auto_migrate!
  end

  #DataMapper.auto_migrate!
  DataMapper.finalize

  # Setup our error handling routine
  error do
    content_type :json
    status 500

    e = env['sinatra.error']
    {:status => 500, :message => e.message}.to_json
  end

  not_found do
    status 404
    'These are not the droids you\'re looking for.' +
    '<br>It would appear that you either forgot to add an extension as a parameter,' +
    '<br>or you did not post any data for processing.' +
    '<br><br>In any case you should probably refer to the <a href="https://github.com/medwards42/polycom-directory-api" target="_blank">README</a>.'
  end


  # Setup the health_check routine
  get '/health_check' do
    status 200
    begin
      "All Systems Go!"
    rescue Exception => e
      raise "Connection to DB not yet working!"
    end


  end


  # Setup the default route handler
  get '/' do
    raise(Sinatra::NotFound)  if params.empty?
  end


  # Setup an index route which will show a list of all ext's in the db.
  get '/index' do
    status 200
    content_type :json
    extensions = Directory.all()
    "#{JSON.pretty_generate(JSON.parse(extensions.to_json()))}"
  end


  # Setup the directory route
  get '/*-directory.*' do
    status 200
    @mac = params[:splat][0].to_s
    @fileExtension = params[:splat][1].to_s
    extension = Directory.all(:mac_address => @mac)
    case @fileExtension
      when "xml"
        content_type :xml
        xml = Builder::XmlMarkup.new( :indent => 2 )
        xml.instruct!
        xml.directory do
          xml.item_list do
            extension.each do |ext|
              xml.item do
                xml.ln ( ext.ln )
                xml.fn ( ext.fn )
                xml.ct ( ext.ct )
                xml.sd ( ext.sd )
                xml.bw ( ext.bw )
              end
            end
          end
        end
      "#{xml.target!}"
      when "json"
        content_type :json
        "#{JSON(extension)}"
      else
        raise "The file type \"#{@fileExtension}\" is not supported at this time."
    end
  end


  # Setup the POST action
  post '/post' do
    entry = Directory.create(:extension => params[:extension],
                             :mac_address => params[:mac_address],
                             :ln => params[:ln],
                             :fn => params[:fn],
                             :ct => params[:ct],
                             :sd => params[:sd],
                             :bw => params[:bw],
                             :active => params[:active] )
    entry.saved? ? "Saved" : "Failed"
  end
end
