# geoip_lookup.py
# Usage: python geoip_lookup.py remote_ips.txt output_dir
# Performs ip-api.com lookups (PUBLIC API) for each IP and writes geoip_results.json
import sys, json, time, urllib.request

def lookup(ip):
    url = f"http://ip-api.com/json/{ip}?fields=status,country,regionName,city,lat,lon,isp,org,as,query"
    with urllib.request.urlopen(url, timeout=10) as r:
        return json.loads(r.read().decode())

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: geoip_lookup.py remote_ips.txt output_dir')
        sys.exit(1)
    ips_file = sys.argv[1]
    outdir = sys.argv[2]
    ips = []
    with open(ips_file,'r') as f:
        for l in f:
            s = l.strip()
            if s: ips.append(s)
    results = []
    for ip in ips:
        try:
            r = lookup(ip)
            results.append(r)
        except Exception as e:
            results.append({'query':ip,'status':'fail','error':str(e)})
        time.sleep(0.4)
    out = outdir + '/geoip_results.json'
    with open(out,'w') as f:
        json.dump(results,f,indent=4)
    print('GeoIP results written to', out)
