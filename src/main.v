module main

import datatypes { DoublyLinkedList }
import gg
import gx
import log
import os

const cache_size = 3

struct App {
mut:
	context    &gg.Context = unsafe { nil }
	filelist   []string
	index      int = -1
	current    int
	prev_cache DoublyLinkedList[thread int]
	next_cache DoublyLinkedList[thread int]
}

fn main() {
	mut logger := log.new_thread_safe_log()
	$if prod {
		logger.set_level(.disabled)
	} $else {
		logger.set_level(.info)
	}
	logger.set_time_format(.tf_ss)
	log.set_logger(logger)

	mut args := os.args.clone()
	args.drop(1)
	filelist, first_index := parse_args(args)
	mut app := &App{
		filelist:   filelist
		index:      first_index - 1
		prev_cache: DoublyLinkedList[thread int]{}
		next_cache: DoublyLinkedList[thread int]{}
	}

	app.context = gg.new_context(
		bg_color:     gx.black
		window_title: 'view'
		width:        600
		height:       400
		init_fn:      init
		frame_fn:     draw
		keydown_fn:   key
		ui_mode:      true
		user_data:    app
	)

	app.context.run()
}

fn init(mut app App) {
	log.info('Filelist: ${app.filelist}')
	if app.filelist.len == 0 {
		return
	}
	for i := 0; app.index - i >= 0 || app.index + i < app.filelist.len; i += 1 {
		res_plus := load(mut app, app.index + i)
		if res_plus >= 0 {
			app.index += i
			app.current = res_plus
			break
		}
		res_minus := load(mut app, app.index - i)
		if res_minus >= 0 {
			app.index -= i
			app.current = res_minus
			break
		}
	}
	for i := 1; i <= cache_size; i += 1 {
		app.prev_cache.push_front(spawn load(mut app, app.index - i))
		app.next_cache.push_back(spawn load(mut app, app.index + i))
	}
	log.info('Index: ${app.index}, ID: ${app.current}')
}

// 読み込まれていない画像を読みとる
fn load(mut app App, index int) int {
	path := app.filelist[index] or { return -1 }
	if image := app.context.create_image(path) {
		idx := app.context.cache_image(image)
		log.info('Image ${path} loaded at ${idx}')
		return idx
	} else {
		return -1
	}
}

fn unload(mut app App, idx int) {
	if idx >= 0 {
		app.context.remove_cached_image_by_idx(idx)
		log.info('Image ${idx} unloaded')
	}
}

enum Direction {
	forward  = 1
	backward = -1
}

fn next(mut app App) {
	move(mut app, .forward)
}

fn prev(mut app App) {
	move(mut app, .backward)
}

fn move(mut app App, direction Direction) {
	offset := int(direction)
	if app.index + offset >= app.filelist.len || app.index + offset < 0 {
		return
	}

	app.index += offset

	// 新規画像を別スレッドで読み込み
	match direction {
		.forward { app.next_cache.push_back(spawn load(mut app, app.index + cache_size)) }
		.backward { app.prev_cache.push_front(spawn load(mut app, app.index - cache_size)) }
	}

	// 古いのをキャッシュから削除
	to_unload := match direction {
		.forward { app.prev_cache.pop_front() or { panic('Application is in invalid state') } }
		.backward { app.next_cache.pop_back() or { panic('Application is in invalid state') } }
	}.wait()
	spawn unload(mut app, to_unload)

	// 今のをキャッシュへ
	current := app.current
	f := fn [current] () int {
		return current
	}
	match direction {
		.forward { app.prev_cache.push_back(spawn f()) }
		.backward { app.next_cache.push_front(spawn f()) }
	}

	// 新しいのを読み込み
	to_draw := match direction {
		.forward { app.next_cache.pop_front() or { return } }
		.backward { app.prev_cache.pop_back() or { return } }
	}
	app.current = to_draw.wait()
	if app.current < 0 {
		move(mut app, direction)
		return
	}
}

fn key(c gg.KeyCode, m gg.Modifier, mut app App) {
	match c {
		.right { next(mut app) }
		.left { prev(mut app) }
		else {}
	}

	log.info('Index: ${app.index}, ID: ${app.current}')
}

fn draw(mut app App) {
	if app.filelist.len == 0 || app.current < 0 {
		return
	}
	image := app.context.get_cached_image_by_idx(app.current)

	window_size := app.context.window_size()

	image_ratio := f64(image.width) / image.height
	window_ratio := f64(window_size.width) / window_size.height

	w, h := match true {
		image_ratio == window_ratio { window_size.width, window_size.height }
		image_ratio > window_ratio { window_size.width, int(image.height * (f64(window_size.width) / image.width)) }
		else { int(image.width * (f64(window_size.height) / image.height)), window_size.height }
	}

	x, y := match true {
		image_ratio == window_ratio { 0, 0 }
		image_ratio > window_ratio { 0, int(f64(window_size.height - h) / 2) }
		else { int(f64(window_size.width - w) / 2), 0 }
	}

	app.context.begin()
	app.context.draw_image(x, y, w, h, image)
	app.context.end()
}
