require 'bundler'
Bundler.require

get '/' do
  send_file 'public/index.html'
end

post '/vasm' do
  dir = "#{File.dirname(__FILE__)}/../"
  Dir.chdir(dir) do
    handle = IO.popen(['lua', 'vasm/v2json.lua'], 'r+')
    asm = request.body.read
    
    puts asm
    handle.write(asm)
    handle.close_write
    resp = handle.read
  end
end
