import json, pathlib, plistlib, subprocess, time
out=pathlib.Path('evidence'); out.mkdir(exist_ok=True)
def run(args, **kw):
    return subprocess.run(args,check=True,text=True,capture_output=True,**kw).stdout
print(run(['xcodebuild','-version']),flush=True)
print(run(['df','-h','.']),flush=True)
devices=json.loads(run(['xcrun','simctl','list','devices','available','-j']))['devices']
choices=[d for runtime,group in devices.items() if 'tvOS' in runtime for d in group if d['isAvailable']]
if not choices: raise SystemExit('No tvOS simulator available')
device=choices[0]; udid=device['udid']; print('Simulator:',device['name'],udid,flush=True)
if device['state']!='Booted':run(['xcrun','simctl','boot',udid])
run(['xcrun','simctl','bootstatus',udid,'-b'])
sdk=run(['xcrun','--sdk','appletvsimulator','--show-sdk-path']).strip()
app=out/'SeyirProbe.app'; app.mkdir(exist_ok=True)
info={'CFBundleIdentifier':'com.chainmedia.seyir.engineprobe','CFBundleName':'SeyirProbe','CFBundleExecutable':'SeyirProbe','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','MinimumOSVersion':'18.0','UIDeviceFamily':[3],'UILaunchScreen':{}}
(app/'Info.plist').write_bytes(plistlib.dumps(info))
run(['xcrun','--sdk','appletvsimulator','clang','-fobjc-arc','-target','arm64-apple-tvos18.0-simulator','-isysroot',sdk,'-framework','UIKit','-framework','Foundation','.seyir-probe/main.m','-o',str(app/'SeyirProbe')])
run(['codesign','--force','--sign','-',str(app)])
run(['xcrun','simctl','install',udid,str(app)])
for mode in ['--inspect','--wk']:
    with (out/(mode[2:]+'.log')).open('w') as log:
        proc=subprocess.Popen(['xcrun','simctl','launch','--terminate-running-process','--console',udid,info['CFBundleIdentifier'],mode],stdout=log,stderr=subprocess.STDOUT)
        try:proc.wait(timeout=22)
        except subprocess.TimeoutExpired:proc.terminate();proc.wait(timeout=5)
    text=(out/(mode[2:]+'.log')).read_text(errors='replace')
    print('\n'.join(x for x in text.splitlines() if 'SEYIR_PROBE' in x or 'Terminating' in x or 'exception' in x),flush=True)
    run(['xcrun','simctl','io',udid,'screenshot',str(out/(mode[2:]+'.png'))])
