import { check } from 'k6';
import crypto from 'k6/crypto';
import exec from 'k6/execution';
import http from 'k6/http';

// med 16.3 ms with Java
// med 57.4 ms with SQL

const n = 2500;
export const options = {
    hosts: { 'localhost' : '172.17.0.1' },	
    setupTimeout: '600s',
    iterations: n,	
    thresholds: {
        'http_reqs{scenario:default}': [],
	'iteration_duration{scenario:default}': [`max>=0`],
        'http_req_duration{scenario:default}': [`max>=0`],
    },
};

const params = { headers: { 'X-Okapi-Tenant': 'diku' } };

export function setup() {
  http.del('http://localhost:8081/item-storage/items?query=id=="44444444-8888-4444-8888-*"', null, params);	
  http.del('http://localhost:8081/holdings-storage/holdings?query=id=="44444444-8888-4444-8888-*"', null, params);
  
  for (let i = 100000; i < 100000 + n; i++) {
    const id = '44444444-8888-4444-8888-' + crypto.md5('' + i, 'hex').slice(-12);
    const holding = {
      id: id,
      hrid: id,	
      instanceId: '69640328-788e-43fc-9c3c-af39e243f3b7',
      permanentLocationId: 'fcd64ce1-6995-48f0-840e-89ffa2288371',
    };
    const res = http.post('http://localhost:8081/holdings-storage/holdings', JSON.stringify(holding), params);
    const ok = check(res, { 'expect status 201': (r) => r.status === 201 });
    if (! ok) {
      console.log('status: ' + res.status + ', body: ' + res.body);
    }
    for (let j = 0; j < 10; j++) {
      const itemId = '44444444-8888-4444-8888-' + j + crypto.md5('' + i, 'hex').slice(-11);	   
      const item = {
        id: itemId,
        holdingsRecordId: id,
        status: { name: 'Available' },
        permanentLoanTypeId: '2b94c631-fca9-4892-a730-03ee529ffe27',
        materialTypeId: '1a54b431-2e4f-452d-9cae-9cee66c9a892',
      };
      const res2 = http.post('http://localhost:8081/item-storage/items', JSON.stringify(item), params);
      const ok2 = check(res, { 'expect status 201': (r) => r.status === 201 });
      if (! ok2) {
        console.log('status: ' + res2.status + ', body: ' + res.body);
      }
    }	
  }
}

export default function() {
  const i = exec.vu.idInTest * 100000 + exec.vu.iterationInInstance;
  const id = '44444444-8888-4444-8888-' + crypto.md5('' + i, 'hex').slice(-12);
  const batch = { holdingsRecords: [ {
    id: id,
    hrid: id,
    instanceId: '69640328-788e-43fc-9c3c-af39e243f3b7',
    permanentLocationId: '53cf956f-c1df-410b-8bea-27f712cca7c0',
    _version: 1,
  }]};
  const res = http.post('http://localhost:8081/holdings-storage/batch/synchronous?upsert=true', JSON.stringify(batch), params);
  const ok = check(res, { 'expect status 201': (r) => r.status === 201 });
  if (! ok) {
    console.log('status: ' + res.status + ', body: ' + res.body);
  }
}
