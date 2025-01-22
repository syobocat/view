module main

import datatypes { DoublyLinkedList }
import gg
import gx
import log
import os
import stbi

const cache_size = 3

struct Cache {
mut:
	last_id i64
	images  map[i64]gg.Image
}

struct App {
mut:
	context    &gg.Context = unsafe { nil }
	filelist   []string
	index      int = -1
	current    i64
	cache      shared Cache
	prev_cache shared DoublyLinkedList[thread i64]
	next_cache shared DoublyLinkedList[thread i64]
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
		filelist: filelist
		index:    first_index - 1
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
	app.context.cache_image(gg.Image{})
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
	update_gg_cache(mut app)
	lock app.prev_cache, app.next_cache {
		for i := 1; i <= cache_size; i += 1 {
			app.prev_cache.push_front(spawn load(mut app, app.index - i))
			app.next_cache.push_back(spawn load(mut app, app.index + i))
		}
	}
	log.info('Index: ${app.index}, ID: ${app.current}')
}

fn update_gg_cache(mut app App) {
	app.context.remove_cached_image_by_idx(0)
	rlock app.cache {
		app.context.cache_image(app.cache.images[app.current] or { panic('Unexpected Error') })
	}
}

// 読み込まれていない画像を読みとる
fn load(mut app App, index int) i64 {
	path := app.filelist[index] or { return -1 }
	if stb_img := stbi.load(path) {
		lock app.cache {
			app.cache.last_id += 1
			idx := app.cache.last_id
			mut img := gg.Image{
				width:       stb_img.width
				height:      stb_img.height
				nr_channels: stb_img.nr_channels
				ok:          stb_img.ok
				data:        stb_img.data
				ext:         stb_img.ext
				path:        path
			}
			img.init_sokol_image()
			app.cache.images[idx] = img
			log.info('Image ${path} loaded at ${idx}')
			return idx
		}
	} else {
		return -1
	}
}

fn unload(mut app App, idx i64) {
	if idx >= 0 {
		lock app.cache {
			unsafe { app.cache.images.delete(idx) }
		}
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
		.forward {
			lock app.next_cache {
				app.next_cache.push_back(spawn load(mut app, app.index + cache_size))
			}
		}
		.backward {
			lock app.prev_cache {
				app.prev_cache.push_front(spawn load(mut app, app.index - cache_size))
			}
		}
	}

	// 古いのをキャッシュから削除
	match direction {
		.forward {
			to_unload := lock app.prev_cache {
				app.prev_cache.pop_front() or { panic('Application is in invalid state') }.wait()
			}
			spawn unload(mut app, to_unload)
		}
		.backward {
			to_unload := lock app.next_cache {
				app.next_cache.pop_back() or { panic('Application is in invalid state') }.wait()
			}
			spawn unload(mut app, to_unload)
		}
	}

	// 今のをキャッシュへ
	current := app.current
	f := fn [current] () i64 {
		return current
	}
	match direction {
		.forward {
			lock app.prev_cache {
				app.prev_cache.push_back(spawn f())
			}
		}
		.backward {
			lock app.next_cache {
				app.next_cache.push_front(spawn f())
			}
		}
	}

	// 新しいのを読み込み
	match direction {
		.forward {
			to_draw := lock app.next_cache {
				app.next_cache.pop_front() or { return }.wait()
			}
			app.current = to_draw
		}
		.backward {
			to_draw := lock app.prev_cache {
				app.prev_cache.pop_back() or { return }.wait()
			}
			app.current = to_draw
		}
	}
	if app.current < 0 {
		move(mut app, direction)
		return
	}
	update_gg_cache(mut app)
	log.info('Index: ${app.index}, ID: ${app.current}')
}

fn key(c gg.KeyCode, m gg.Modifier, mut app App) {
	match c {
		.right { next(mut app) }
		.left { prev(mut app) }
		else {}
	}
}

fn draw(mut app App) {
	image := rlock app.cache {
		app.cache.images[app.current] or { return }
	}

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
	app.context.draw_image_by_id(x, y, w, h, 0)
	app.context.end()
}
