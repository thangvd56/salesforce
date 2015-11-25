require "sinatra/base"
require 'force'
require "omniauth"
require "omniauth-salesforce"
require "bootstrap"


class MyApp < Sinatra::Base

  configure do
    enable :logging
    enable :sessions
    set :show_exceptions, false
    set :session_secret, ENV['SECRET']
  end

  use OmniAuth::Builder do
    provider :salesforce, ENV['SALESFORCE_KEY'], ENV['SALESFORCE_SECRET']
  end

  before /^(?!\/(auth.*))/ do   
    redirect '/authenticate' unless session[:instance_url]
  end


  helpers do
    def client
      @client ||= Force.new instance_url:  session['instance_url'], 
                            oauth_token:   session['token'],
                            refresh_token: session['refresh_token'],
                            client_id:     ENV['SALESFORCE_KEY'],
                            client_secret: ENV['SALESFORCE_SECRET']
    end

  end


  get '/' do
    logger.info "Visited home page"
    @accounts= client.query("select Id, Name, username__c, email__c, teamnumber__c, Team__r.Name from Employees__c")    
    erb :index
  end

  get '/account/:id' do
    @infors = client.query("select Id, Name from Employees__c where Id = '#{params[:id]}'")
    erb :account
  end

  get '/register' do
    @teams = client.query("select Name, teamkey__c from Team__c")
    erb :register
  end

  post '/register' do
    new_employee = Array.new
    new_employee << {'Name' => params[:fullname], 'username__c' => params[:username], 'Address__c' => params[:address], 'birthday__c'=> params[:dateofb], 
      'Hiredate__c' => params[:hiredate], 'Phone__c' => params[:phone], 'email__c'=> params[:email], 'Position__c' => params[:position], 'Team__c'=> params[:team]}
    result = client.create('Employees__c', new_employee)
    if result
      redirect '/'
    else
      redirect '/register'
    end
    # client.create('Employees__c', Name: params[:fullname], username__c: params[:username], Address__c: params[:address], birthday__c: params[:dateofb], 
    #   Hiredate__c: params[:hiredate], Phone__c: params[:phone], email__c: params[:email], Position__c: params[:position], Team__c: params[:team])
    
  end

  get '/addteam' do
    erb :addteam
  end

  post '/addteam' do
    result = client.create('Team__c', Name: params[:teamname], teamkey__c: params[:teamkey])
    if result
      redirect '/'
    else
      redirect '/addteam'
    end
  end

  get '/details/:id' do
    @employees = client.query("select Name, Position__c, Hiredate__c, birthday__c, Team__r.Name, Address__c, email__c, Phone__c from Employees__c where Id = '#{params[:id]}'")
    erb :details
  end

  get '/authenticate' do
    redirect "/auth/salesforce"
  end


  get '/auth/salesforce/callback' do
    logger.info "#{env["omniauth.auth"]["extra"]["display_name"]} just authenticated"
    credentials = env["omniauth.auth"]["credentials"]
    session['token'] = credentials["token"]
    session['refresh_token'] = credentials["refresh_token"]
    session['instance_url'] = credentials["instance_url"]
    redirect '/'
  end

  get '/auth/failure' do
    params[:message]
  end

  get '/unauthenticate' do
    session.clear 
    'Goodbye - you are now logged out'
  end

  error Force::UnauthorizedError do
    redirect "/auth/salesforce"
  end

  error do
    "There was an error.  Perhaps you need to re-authenticate to /authenticate ?  Here are the details: " + env['sinatra.error'].name
  end

  run! if app_file == $0

end
