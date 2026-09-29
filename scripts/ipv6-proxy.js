import http from 'node:http';
import net from 'node:net';
import dns from 'node:dns/promises';

const NAT64_DNS_SERVER = '2a01:4f8:c2c:123f::1';

const KNOWN_MAP = {
  'github.com': '2a00:1098:2b::1:8c52:7903',
  'api.github.com': '2a00:1098:2b::1:8c52:7905',
  'uploads.github.com': '2a00:1098:2b::1:8c52:790e',
  'alambic-origin.githubusercontent.com': '2a00:1098:2b::1:8c52:790e',
  'objects.githubusercontent.com': '2a00:1098:2b::1:8c52:790e',
  'raw.githubusercontent.com': '2a00:1098:2b::1:8c52:790e',
};

async function resolveTarget(hostname) {
  if (KNOWN_MAP[hostname]) return KNOWN_MAP[hostname];
  try {
    const resolver = new dns.Resolver();
    resolver.setServers([NAT64_DNS_SERVER]);
    const addresses = await resolver.resolve6(hostname);
    if (addresses && addresses.length > 0) return addresses[0];
  } catch {
    // fallback
  }
  return hostname;
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Proxy active');
});

server.on('connect', async (req, clientSocket, head) => {
  const [hostname, port] = req.url.split(':');
  const targetPort = parseInt(port || '443', 10);
  const targetIp = await resolveTarget(hostname);

  const serverSocket = net.connect({ host: targetIp, port: targetPort }, () => {
    clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
    serverSocket.write(head);
    serverSocket.pipe(clientSocket);
    clientSocket.pipe(serverSocket);
  });

  serverSocket.on('error', () => {
    clientSocket.end();
  });
  clientSocket.on('error', () => {
    serverSocket.end();
  });
});

server.listen(8989, '127.0.0.1', () => {
  console.log('IPv6 Forward Proxy listening on 127.0.0.1:8989');
});
