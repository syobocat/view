module main

import os

const supported_ext = ['.png', '.jpg']

fn parse_args(args []string) ([]string, int) {
	normalized_args := args.map(if os.is_dir(it) { '${it}/' } else { it })

	// 引数がなければカレントディレクトリを指定
	targets := match normalized_args.len {
		0 { ['.'] }
		1 { [os.dir(normalized_args[0])] }
		else { normalized_args.clone() }
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

	file_list := ret.filter(os.file_ext(it) in supported_ext).map(os.abs_path(it))

	first_index := if args.len == 1 {
		i := file_list.index(os.abs_path(args[0]))
		if i > 0 {
			i
		} else {
			0
		}
	} else {
		0
	}

	return file_list, first_index
}

fn get_filelist(dir string) []string {
	mut files := os.ls(dir) or { []string{} }
	files.sort_with_compare(natural_cmp)
	return files.map(os.join_path(dir, it))
}
