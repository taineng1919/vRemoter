import Foundation
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".local/tests/recordings")
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
let wav=root.appendingPathComponent("replaced.wav")
var recorder:WavRecorder?=WavRecorder(wavURL:wav,rawURL:root.appendingPathComponent("replaced.raw.bin"),basename:"replaced")
recorder?.appendSamples([0,100,-100,200,-200,300,-300,0])
recorder=nil
let d=try Data(contentsOf:wav)
let count=UInt32(d[40])|UInt32(d[41])<<8|UInt32(d[42])<<16|UInt32(d[43])<<24
guard count==16,d.count==60 else{fputs("FAIL: replaced stream has unfinalized WAV header\n",stderr);exit(1)}
print("PASS: replacing an active recorder finalizes its WAV header")
