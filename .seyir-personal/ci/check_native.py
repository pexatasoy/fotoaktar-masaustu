"""Build and capture the real personal tvOS app on a macOS CI runner."""
import json, pathlib, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parent.parent
OUT=pathlib.Path.cwd()/'evidence';OUT.mkdir(exist_ok=True)
def run(args, **kw):
    result=subprocess.run(args,text=True,capture_output=True,**kw)
    if result.returncode:
        print(result.stdout[-2000:]);print(result.stderr[-4000:]);result.check_returncode()
    return result.stdout
def build(sdk,configuration):
    args=['xcodebuild','-project',str(ROOT/'Seyir.xcodeproj'),'-scheme','Seyir','-sdk',sdk,'-configuration',configuration,'-derivedDataPath',str(OUT/sdk),'CODE_SIGNING_ALLOWED=NO','GCC_PREPROCESSOR_DEFINITIONS=$(inherited) SEYIR_PERSONAL_BUILD=1 SEYIR_DIAGNOSTICS='+('1' if configuration=='Debug' else '0'),'build']
    with (OUT/(sdk+'.log')).open('w') as log:
        code=subprocess.call(args,stdout=log,stderr=subprocess.STDOUT)
    if code:
        print('\n'.join(x for x in (OUT/(sdk+'.log')).read_text().splitlines() if 'error:' in x));raise SystemExit(code)
    print('Build succeeded:',sdk,flush=True)
print(run(['xcodebuild','-version']),flush=True)
run(['xcodegen','generate','--spec',str(ROOT/'project.yml'),'--project',str(ROOT)])
run(['xcrun','clang','-fobjc-arc','-framework','Foundation',str(ROOT/'tests/address_tests.m'),str(ROOT/'native/SeyirAddress.m'),str(ROOT/'native/SeyirLibrary.m'),'-o',str(OUT/'address-tests')])
print(run([str(OUT/'address-tests')]),flush=True)
build('appletvsimulator','Debug')
build('appletvos','Release')
devices=json.loads(run(['xcrun','simctl','list','devices','available','-j']))['devices']
choices=[d for runtime,group in devices.items() if 'tvOS' in runtime for d in group if d['isAvailable']]
if not choices:raise SystemExit('No tvOS simulator')
device=choices[0];uid=device['udid']
if device['state']!='Booted':run(['xcrun','simctl','boot',uid])
run(['xcrun','simctl','bootstatus',uid,'-b'],timeout=300)
app=OUT/'appletvsimulator/Build/Products/Debug-appletvsimulator/Seyir.app'
run(['xcrun','simctl','install',uid,str(app)])
for mode in ['--home','--test-google','--test-youtube','--test-video']:
    with (OUT/(mode[2:]+'.log')).open('w') as log:
        proc=subprocess.Popen(['xcrun','simctl','launch','--terminate-running-process','--console',uid,'com.chainmedia.seyir.personal',mode],stdout=log,stderr=subprocess.STDOUT)
        try:proc.wait(timeout=35 if mode!='--home' else 12)
        except subprocess.TimeoutExpired:
            run(['xcrun','simctl','io',uid,'screenshot',str(OUT/(mode[2:]+'.png'))])
            proc.terminate();proc.wait(timeout=5)
    text=(OUT/(mode[2:]+'.log')).read_text(errors='replace')
    print('\n'.join(x for x in text.splitlines() if 'SEYIR_TEST' in x or 'Terminating' in x or 'exception' in x),flush=True)
    if 'Terminating app due to' in text:raise SystemExit('Application crashed')
    if mode!='--home' and 'SEYIR_TEST result=' not in text:raise SystemExit('Missing page-test completion: '+mode)
print('Compilation and page probes completed. Inspect media results before claiming playback.',flush=True)
