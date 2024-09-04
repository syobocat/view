module main

import math

fn natural_cmp(a &string, b &string) int {
	if a == b {
		return 0
	}
	if a.len == 0 && b.len == 0 {
		return 0
	}
	if a.len == 0 {
		return -1
	}
	if b.len == 0 {
		return 1
	}

	chunk_a := split_into_chunks(a)
	chunk_b := split_into_chunks(b)

	for i in 0 .. math.min(chunk_a.len, chunk_b.len) {
		if chunk_a[i].is_int() && chunk_b[i].is_int() {
			if chunk_a[i].int() < chunk_b[i].int() {
				return -1
			}
			if chunk_a[i].int() > chunk_b[i].int() {
				return 1
			}
		} else {
			if chunk_a[i] < chunk_b[i] {
				return -1
			}
			if chunk_a[i] > chunk_b[i] {
				return 1
			}
		}
	}

	if a.len < b.len {
		return -1
	} else {
		return 1
	}
}

fn split_into_chunks(s string) []string {
	if s.len == 0 {
		return []string{}
	}
	mut ret := []string{}
	mut is_num := s[0].is_digit()
	mut from := 0

	for i, c in s {
		if c.is_digit() != is_num {
			ret << s[from..i]
			from = i
			is_num = !is_num
		}
	}
	ret << s[from..]

	return ret
}
