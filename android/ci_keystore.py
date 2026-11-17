import base64
import os
import re
import subprocess
import sys

def run_cmd(cmd):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return p.returncode, p.stdout

def main():
    keystore_b64 = os.environ.get('KEYSTORE', '').strip()
    password = os.environ.get('PASSWORD', '').strip()
    github_output = os.environ.get('GITHUB_OUTPUT', '')

    os.makedirs('android', exist_ok=True)
    jks_path = os.path.join('android', 'release.jks')
    key_props_path = os.path.join('android', 'key.properties')

    alias = 'release'
    storepass = password
    cert_info = ''

    used_secret = False
    if keystore_b64 and password:
        print('Repository secrets detected. Attempting to decode release keystore...')
        try:
            clean_b64 = re.sub(r'\s+', '', keystore_b64)
            data = base64.b64decode(clean_b64)
            with open(jks_path, 'wb') as f:
                f.write(data)
            code, out = run_cmd(['keytool', '-list', '-v', '-keystore', jks_path, '-storepass', password])
            if code == 0:
                print('Secret release keystore verified successfully!')
                cert_info = out
                used_secret = True
                m_alias = re.search(r'Alias name:\s*(.+)', out, re.IGNORECASE)
                if m_alias:
                    alias = m_alias.group(1).strip()
            else:
                print(f'::warning::Provided secret keystore verification failed (code {code}): {out}')
        except Exception as e:
            print(f'::warning::Error decoding secret keystore: {e}')

    if not used_secret:
        print('Using dedicated CI test signing keystore for testing artifact APKs...')
        storepass = 'IceDragonHubTest2026!'
        alias = 'release'
        if os.path.exists(jks_path):
            os.remove(jks_path)
        gen_cmd = [
            'keytool', '-genkeypair', '-v',
            '-keystore', jks_path,
            '-alias', alias,
            '-keyalg', 'RSA',
            '-keysize', '2048',
            '-validity', '10000',
            '-storepass', storepass,
            '-keypass', storepass,
            '-dname', 'CN=IceDragon AppHub Test, OU=Dev, O=IceDragon, C=IR',
        ]
        code, out = run_cmd(gen_cmd)
        if code != 0:
            print(f'::error::keytool genkeypair failed (code {code}): {out}')
            sys.exit(1)

        code, cert_info = run_cmd(['keytool', '-list', '-v', '-keystore', jks_path, '-storepass', storepass, '-alias', alias])
        if code != 0:
            print(f'::error::keytool list failed (code {code}): {cert_info}')
            sys.exit(1)

    m_sha = re.search(r'SHA-?256:\s*([0-9A-Fa-f:]+)', cert_info)
    if not m_sha:
        print(f'::error::Failed to extract SHA-256 fingerprint from keystore output:\n{cert_info}')
        sys.exit(1)

    raw_sha = m_sha.group(1).replace(':', '').strip().lower()
    if len(raw_sha) != 64:
        print(f'::error::Extracted fingerprint is invalid (length {len(raw_sha)} != 64): {raw_sha}')
        sys.exit(1)

    print(f'Successfully configured signing keystore. Alias: {alias}, Certificate SHA-256: {raw_sha}')

    with open(key_props_path, 'w', encoding='utf-8') as f:
        f.write(f'storeFile=release.jks\nstorePassword={storepass}\nkeyAlias={alias}\nkeyPassword={storepass}\n')

    if github_output:
        with open(github_output, 'a', encoding='utf-8') as f:
            f.write(f'sha256={raw_sha}\n')

if __name__ == '__main__':
    main()
