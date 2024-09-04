module main

import os

const supported_ext = ['.png', '.jpg']

fn parse_args(args []string) []string {
	// 引数がなければカレントディレクトリを指定
	targets := if args.len == 0 {
		['.']
	} else {
		args.clone()
	}

	mut ret := []string{}
	for target in targets {
		if !os.exists(target) {
			continue
		}

		if os.is_dir(target) {
			ret << get_filelist(target)
		} else {
			ret << target
		}
	}

	return ret.filter(os.file_ext(it) in supported_ext).map(os.abs_path(it))
}

fn get_filelist(dir string) []string {
	mut files := os.ls(dir) or { []string{} }
	files.sort_with_compare(natural_cmp)
	return files.map(os.join_path(dir, it))
}
