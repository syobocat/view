module main

import gg
import gx
import os

struct App {
mut:
	context  &gg.Context = unsafe { nil }
	filelist []string
	index    int
	prev     int = -1
	current  int = -1
	next     int = -1
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
		init_fn:  init
		frame_fn: draw
		// resized_fn: redraw
		keydown_fn: key
		ui_mode:    true
		user_data:  app
	)

	app.context.run()
}

fn init(mut app App) {
	app.prev = -1
	app.current = if app.filelist.len == 0 {
		-1
	} else {
		if image := app.context.create_image(app.filelist[0]) {
			app.context.cache_image(image)
		} else {
			-1
		}
	}
	app.next = if app.filelist.len < 2 {
		-1
	} else {
		if image := app.context.create_image(app.filelist[1]) {
			app.context.cache_image(image)
		} else {
			-1
		}
	}
}

fn load_next(mut app App) {
	if app.next == -1 {
		return
	}
	app.index += 1
	if app.prev != -1 {
		app.context.remove_cached_image_by_idx(app.prev)
	}
	app.prev = app.current
	app.current = app.next
	app.next = if app.filelist.len <= app.index + 1 {
		-1
	} else {
		if image := app.context.create_image(app.filelist[app.index + 1]) {
			app.context.cache_image(image)
		} else {
			-1
		}
	}
}

fn load_prev(mut app App) {
	if app.prev == -1 {
		return
	}
	app.index -= 1
	if app.next != -1 {
		app.context.remove_cached_image_by_idx(app.next)
	}
	app.next = app.current
	app.current = app.prev
	app.prev = if app.index < 1 {
		-1
	} else {
		if image := app.context.create_image(app.filelist[app.index - 1]) {
			app.context.cache_image(image)
		} else {
			-1
		}
	}
}

fn key(c gg.KeyCode, m gg.Modifier, mut app App) {
	match c {
		.right { load_next(mut app) }
		.left { load_prev(mut app) }
		else {}
	}
}

fn draw(mut app App) {
	if app.current == -1 {
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
