#!/usr/bin/env python3
"""Explicit network QA on Final Fresh Build 0927 only; creates synthetic fixtures.

Never part of the automatic test suite. Requires a fresh synthetic student number.
Tokens and recovery codes stay in memory and are never printed.
"""
import argparse
import concurrent.futures
import json
import secrets
import threading
import urllib.error
import urllib.request
import uuid

BASE = 'https://bvtqcrxczmrwclvjxonb.supabase.co'
KEY = 'sb_publishable_fymygErxyId0x3fZykasIg_-DCBsX2M'


def post(path, data, token=None):
    headers = {'apikey': KEY, 'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(BASE + path, data=json.dumps(data).encode(), headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--student', required=True)
    args = parser.parse_args()
    assert args.student.startswith('990927') and len(args.student) == 8 and args.student.isascii() and args.student.isdigit()
    fullwidth = args.student.translate(str.maketrans('0123456789', '０１２３４５６７８９'))
    sessions = []
    for _ in range(2):
        status, session = post('/auth/v1/signup', {'data': {'qa_purpose': 'final-concurrent-registration'}})
        assert status == 200, 'Synthetic sign-in failed'
        sessions.append(session)
    code = 'QAR9' + secrets.token_hex(8)
    barrier = threading.Barrier(2)

    def register(index):
        barrier.wait()
        return post('/rest/v1/rpc/create_player_account', {
            'p_account_type': 'student', 'p_student_number': [args.student, fullwidth][index],
            'p_player_name': 'QA-RACE-' + args.student[-2:] + str(index), 'p_course_code': 'piano',
            'p_recovery_code': code, 'p_avatar_id': 'nova',
        }, sessions[index]['access_token'])

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(register, range(2)))
    assert sum(status == 200 for status, _ in results) == 1, 'Concurrent registration did not produce exactly one winner'
    winner = next(i for i, (status, _) in enumerate(results) if status == 200)
    loser = 1 - winner
    assert 'already registered' in results[loser][1].get('message', '') or results[loser][1].get('code') == '23505', 'Unexpected loser error'
    player = results[winner][1][0]['player_id']
    token = sessions[winner]['access_token']
    other = sessions[loser]['access_token']
    print('PASS concurrent ASCII/fullwidth registration: exactly one account')
    status, _ = post('/rest/v1/rpc/submit_saved_play', {
        'p_player_id': player, 'p_visibility': 'ask', 'p_payload': {
            'clientEventId': str(uuid.uuid4()), 'source': 'ranked', 'mode': 'TEXT', 'score': 19,
            'totalAnswers': 1, 'correctAnswers': 1, 'maxCombo': 1, 'avgResponse': 500,
        }}, token)
    assert status == 200, 'Private score fixture failed'
    status, result = post('/rest/v1/rpc/recover_student_account', {
        'p_student_number': args.student, 'p_recovery_code': 'Incorrect99'}, other)
    assert status == 200 and result.get('ok') is False and result.get('code') == 'invalid_credentials'
    status, linked = post('/rest/v1/rpc/current_player_id', {}, other)
    assert status == 200 and linked is None, 'Wrong recovery linked account'
    print('PASS incorrect recovery code leaves session unlinked')
    status, result = post('/rest/v1/rpc/recover_student_account', {
        'p_student_number': fullwidth, 'p_recovery_code': code.lower()}, other)
    assert status == 200 and result.get('ok') is True, 'Correct recovery failed'
    for session in sessions:
        status, linked = post('/rest/v1/rpc/current_player_id', {}, session['access_token'])
        assert status == 200 and linked == player, 'Recovery lost original membership'
    print('PASS normalized recovery: both sessions reference the same player')
    print('Retained synthetic fixture:', args.student, player)


if __name__ == '__main__':
    main()
