import Foundation
var events = [String]()
var selected: InputTriggerKey = .function
func check(_ condition: Bool, _ message: String) {
    guard condition else {fputs("FAIL: \(message)\n",stderr);exit(1)}
    print("PASS: \(message)")
}
let held = RecognitionTrigger(functionIsHold:{true},key:{selected},down:{events.append("down:\($0.rawValue)")},up:{events.append("up:\($0.rawValue)")},tap:{events.append("tap:\($0.rawValue)")})
held.toggle()
check(events == ["down:function"], "Fn hold opens without a premature key-up")
held.toggle()
check(events == ["down:function","up:function"], "second recognition transition releases Fn")
held.toggle();held.release();held.release()
check(events == ["down:function","up:function","down:function","up:function"], "stop/disconnect cleanup releases exactly once")
selected = .option;held.toggle()
check(events.last == "tap:option", "ordinary Option toggle remains unchanged")
events=[];selected = .function
let legacy = RecognitionTrigger(functionIsHold:{false},key:{selected},down:{events.append("down:\($0.rawValue)")},up:{events.append("up:\($0.rawValue)")},tap:{events.append("tap:\($0.rawValue)")})
legacy.toggle();legacy.release()
check(events == ["tap:function"], "existing Fn toggle is unchanged without candidate opt-in")

// Configuration changes cannot turn a held Fn into an unrelated tap.
events=[];selected = .function
var holdMode = true
let changing = RecognitionTrigger(functionIsHold:{holdMode},key:{selected},down:{events.append("down:\($0.rawValue)")},up:{events.append("up:\($0.rawValue)")},tap:{events.append("tap:\($0.rawValue)")})
changing.toggle();selected = .option;holdMode = false;changing.toggle()
check(events == ["down:function","up:function"], "configuration change finishes the held Fn without tapping another key")
selected = .function;holdMode = true;changing.toggle();changing.release()
check(events.suffix(2) == ["down:function","up:function"], "configured hold mode is read again for a new session")
