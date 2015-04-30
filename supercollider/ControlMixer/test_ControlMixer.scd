// test file for ControlMixer

c = ControlMixer( NetAddr("localhost", 57120), "/test1" );

d = ControlMixer( NetAddr("localhost", 57120), "/test2" );

OSCdef(\cmtest1, {|msg, time, addr, recvPort| msg.postln}, '/test1', n); // def style

OSCdef(\cmtest2, {|msg, time, addr, recvPort| msg.postln}, '/test2', n); // def style