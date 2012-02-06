
#!/usr/bin/env ruby

require 'vizkit'
require 'test/unit'
Orocos.initialize

Vizkit.logger.level = Logger::INFO
    
class LoaderUiTest < Test::Unit::TestCase
    def setup
    end

    def test_proxy
        task = Vizkit::TaskProxy.new("port_proxy")
        proxy_reader = nil
        writer = nil 
        reader = nil

        assert (!task.ping)
        assert (!task.has_port?("bla"))

        Orocos.run "rock_port_proxy" do 
            assert (task.ping)
            assert (!task.has_port?("bla"))

            task.start

            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            #test without port_proxyxy
            writer = task.in_test.writer
            reader = task.out_test.reader
            assert(writer)
            assert(reader)

            writer.write Time.now 
            reader.read
            sleep(0.2)
            assert(reader.read)

            #test with port_proxy
            #we are connecting the proxy with itsself to test setting up the port_proxy
            proxy_reader = task.port("out_test")
            assert(proxy_reader)
            proxy_reader = proxy_reader.reader(:port_proxy => "port_proxy") #use task port_proxy as proxy
            assert(proxy_reader)
            writer.write Time.now 
            sleep 0.2
            assert(proxy_reader.read)
            puts "#### NOW I AM KILLING THE PROXY TO TEST RECONNECT #####"
        end

        #testing reconnecting
        assert(!task.ping)
        Orocos.run "rock_port_proxy" do 
            puts "#### RESTART PROXY #####"
            assert (task.ping)
            assert (!task.has_port?("bla"))
            task.start

            #create ports again
            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            proxy_reader.read # this should reconnect the proxy
            writer.write Time.now 
            sleep 0.2
            assert(proxy_reader.read)
        end
    end

    def test_proxy_subfield_reading
        Orocos.run "rock_port_proxy" do 
            task = Vizkit::TaskProxy.new("port_proxy")
            task.start

            assert(task.createProxyConnection("test","/base/samples/frame/FramePair",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            writer = task.in_test.writer
            reader = task.out_test.reader
            assert(writer)
            assert(reader)

            sample = Types::Base::Samples::Frame::FramePair.new
            time_first = Time.now-1000
            sample.time = Time.now
            sample.first.time = time_first
            sample.first.received_time = Time.now
            sample.first.frame_mode = :MODE_UNDEFINED
            sample.first.frame_status = :STATUS_EMPTY
            sample.second.time = Time.now
            sample.second.received_time = Time.now
            sample.second.frame_mode = :MODE_UNDEFINED
            sample.second.frame_status = :STATUS_EMPTY
            writer.write sample 
            sleep(0.2)
            assert(reader.read)

            #create a subfield reader
            subfield_port = task.out_test(:subfield => "first",:type_name =>"/base/samples/frame/Frame")
            assert(subfield_port)
            assert(subfield_port.type_name == "/base/samples/frame/Frame")
            reader = subfield_port.reader
            
            subfield_port2 = task.out_test(:subfield => ["first","size"],:type_name =>"/base/samples/frame/frame_size_t")
            assert(subfield_port2)
            assert(subfield_port2.type_name == "/base/samples/frame/frame_size_t")
            reader2 = subfield_port2.reader

            writer.write sample 
            sleep(0.2)
            assert(reader.read.time == time_first) 
            assert(reader2.read) 
        end
    end
end
