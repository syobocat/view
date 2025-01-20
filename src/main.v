module main

import gg
import gx
import os

struct App {
mut:
	context  &gg.Context = unsafe { nil }
	filelist []string
	index    int = -1
	ids      []int
}

fn main() {
	mut args := os.args.clone()
	args.drop(1)
	filelist, first_index := parse_args(args)
	mut app := &App{
		filelist: filelist
		index:    first_index - 1
		ids:      []int{len: filelist.len, init: -1}
	}

	$if !prod {
		println(app.filelist)
	}

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
	if app.filelist.len > 0 {
		advance(mut app, 1)
	}
}

// 読み込まれていない画像を読みとる
// 成功でtrue、失敗でfalseを返す
fn load(mut app App) !bool {
	if app.ids[app.index] != -1 {
		return error('Image already loaded')
	}
	if image := app.context.create_image(app.filelist[app.index]) {
		app.ids[app.index] = app.context.cache_image(image)
		return true
	} else {
		return false
	}
}

// count枚進める
// 画像が読み込まれていない場合は読み込む
// 読み込めなければ一つ通り越す
fn advance(mut app App, count int) {
	is_last := app.index + count >= app.ids.len
	is_first := app.index + count < 0

	if is_last {
		app.index = app.ids.len - 1
	} else if is_first {
		app.index = 0
	} else {
		app.index += count
	}
	if app.ids[app.index] == -1 {
		if result := load(mut app) {
			if !result {
				if is_last {
					advance(mut app, -1)
				} else {
					advance(mut app, count)
				}
			}
		}
	}

	gg.set_window_title(app.filelist[app.index])
}

fn key(c gg.KeyCode, m gg.Modifier, mut app App) {
	match c {
		.right { advance(mut app, 1) }
		.left { advance(mut app, -1) }
		else {}
	}

	$if !prod {
		println('=====')
		println('${app.ids}')
		println('index: ${app.index}')
	}
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

	x, y := match true {
		image_ratio == window_ratio { 0, 0 }
		image_ratio > window_ratio { 0, int(f64(window_size.height - h) / 2) }
		else { int(f64(window_size.width - w) / 2), 0 }
	}

	app.context.begin()
	app.context.draw_image(x, y, w, h, image)
	app.context.end()
}
