"""Sign for registered personal devices; never uploads to App Store Connect."""
import base64, os, pathlib, plistlib, secrets, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parent.parent
BUNDLE='com.chainmedia.seyir.personal'
OUT=pathlib.Path.cwd()/'signed';OUT.mkdir(exist_ok=True)
def call(args,log=None):
    result=subprocess.run(args,stdout=log or subprocess.PIPE,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError('Signing command failed: '+args[0]+' '+args[1])
    return result.stdout
def secret_file(path,data):
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'wb') as f:f.write(data)
with tempfile.TemporaryDirectory(prefix='seyir-sign-') as temp:
    temp=pathlib.Path(temp)
    profile=temp/'personal.mobileprovision';secret_file(profile,base64.b64decode(os.environ['SEYIR_PERSONAL_PROFILE']))
    decoded=plistlib.loads(call(['security','cms','-D','-i',str(profile)]))
    if not decoded.get('ProvisionedDevices') or 'tvOS' not in decoded.get('Platform',[]):
        raise RuntimeError('A registered-device tvOS profile is required')
    team=decoded['TeamIdentifier'][0]
    if decoded['Entitlements'].get('application-identifier')!=team+'.'+BUNDLE:
        raise RuntimeError('Profile belongs to a different app')
    destination=pathlib.Path.home()/'Library/MobileDevice/Provisioning Profiles'/f"{decoded['UUID']}.mobileprovision"
    destination.parent.mkdir(parents=True,exist_ok=True)
    secret_file(destination,profile.read_bytes())
    p12=temp/'identity.p12';secret_file(p12,base64.b64decode(os.environ['IMZA_P12']))
    keychain=temp/'personal.keychain-db';password=secrets.token_urlsafe(24)
    try:
        call(['security','create-keychain','-p',password,str(keychain)])
        call(['security','set-keychain-settings','-lut','21600',str(keychain)])
        call(['security','unlock-keychain','-p',password,str(keychain)])
        call(['security','import',str(p12),'-P',os.environ['IMZA_P12_PAROLA'],'-A','-t','cert','-f','pkcs12','-k',str(keychain)])
        call(['security','set-key-partition-list','-S','apple-tool:,apple:,codesign:','-s','-k',password,str(keychain)])
        call(['security','list-keychains','-d','user','-s',str(keychain),'login.keychain-db'])
        call(['xcodegen','generate','--spec',str(ROOT/'project.yml'),'--project',str(ROOT)])
        with (OUT/'archive.log').open('wb') as log:
            call(['xcodebuild','archive','-project',str(ROOT/'Seyir.xcodeproj'),'-scheme','Seyir','-configuration','Release','-destination','generic/platform=tvOS','-archivePath',str(OUT/'Seyir.xcarchive'),'DEVELOPMENT_TEAM='+team,'CODE_SIGN_STYLE=Manual','CODE_SIGN_IDENTITY=Apple Distribution','PROVISIONING_PROFILE_SPECIFIER='+decoded['Name'],'CURRENT_PROJECT_VERSION='+os.environ.get('GITHUB_RUN_NUMBER','1')],log)
        export=temp/'export.plist'
        export.write_bytes(plistlib.dumps({'method':'release-testing','teamID':team,'signingStyle':'manual','provisioningProfiles':{BUNDLE:decoded['Name']}}))
        with (OUT/'export.log').open('wb') as log:
            call(['xcodebuild','-exportArchive','-archivePath',str(OUT/'Seyir.xcarchive'),'-exportPath',str(OUT/'package'),'-exportOptionsPlist',str(export)],log)
        print('Signed personal-device package created.')
    finally:
        subprocess.run(['security','delete-keychain',str(keychain)],capture_output=True)
        destination.unlink(missing_ok=True)
