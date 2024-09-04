module main

import gg
import gx
import os

struct App {
mut:
	context     &gg.Context = unsafe { nil }
	filelist    []string
	index       int = -1
	last_loaded int = -1
	ids         []int
}

fn main() {
	mut app := &App{}

	mut args := os.args.clone()
	args.drop(1)
	app.filelist = parse_args(args)

	println(app.filelist)

	app.context = gg.new_context(
		bg_color: gx.black
		width:    600
		height:   400
		init_fn:  load_next
		frame_fn: draw
		// resized_fn: redraw
		keydown_fn: key
		ui_mode:    true
		user_data:  app
	)

	app.context.run()
}

fn load_next(mut app App) {
	if app.last_loaded == app.filelist.len - 1 && app.index == app.ids.len - 1 {
		return
	}

	if image := app.context.create_image(app.filelist[app.last_loaded + 1]) {
		app.last_loaded += 1
		app.ids << app.context.cache_image(image)
	} else {
		app.last_loaded += 1
		load_next(mut app)
	}
	app.index += 1
}

fn go_next(mut app App) {
	if app.index == app.ids.len - 1 {
		load_next(mut app)
	} else {
		app.index += 1
	}
}

fn go_prev(mut app App) {
	if app.index > 0 {
		app.index -= 1
	}
}

fn key(c gg.KeyCode, m gg.Modifier, mut app App) {
	match c {
		.right { go_next(mut app) }
		.left { go_prev(mut app) }
		else {}
	}

	println('=====')
	println('${app.ids}')
	println('      index: ${app.index}')
	println('last_loaded: ${app.last_loaded}')
}

fn draw(mut app App) {
	if app.ids.len == 0 {
		return
	}

	image := app.context.get_cached_image_by_idx(app.ids[app.index])

	window_size := app.context.window_size()

	image_ratio := f64(image.width) / image.height
	window_ratio := f64(window_size.width) / window_size.height

	w, h := match true {
		image_ratio == window_ratio { window_size.width, window_size.height }
		image_ratio > window_ratio { window_size.width, int(image.height * (f64(window_size.width) / image.width)) }
		else { int(image.width * (f64(window_size.height) / image.height)), window_size.height }
	}

	// println('window: ${window_size.width}x${window_size.height}')
	// println(' image: ${image.width}x${image.height}')
	// println('  draw: ${w}x${h}')

	x, y := match true {
		image_ratio == window_ratio { 0, 0 }
		image_ratio > window_ratio { 0, int(f64(window_size.height - h) / 2) }
		else { int(f64(window_size.width - w) / 2), 0 }
	}

	app.context.begin()
	app.context.draw_image(x, y, w, h, image)
	app.context.end()
}
