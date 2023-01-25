//
//  ContentView.swift
//  Metal-SwiftUI
//

import SwiftUI
import MetalKit


struct ContentView: View {
	let renderer = Renderer()

	var body: some View {
		if let renderer = self.renderer {
			MetalView(device: renderer.device) {
				renderer.render(to: $0, using: $1, size: $2)
			}
		} else {
			Text("Failed to initialize renderer")
		}
	}
}


struct MetalView: NSViewRepresentable {

	typealias Draw = (MTLDrawable, MTLRenderPassDescriptor, CGSize) -> Void
	let device: MTLDevice
	let draw: Draw

	func makeCoordinator() -> Coordinator { .init(draw: self.draw) }

	func makeNSView(context: Context) -> MetalKit.MTKView {
		let view = MetalKit.MTKView(frame: .zero, device: self.device)
		view.delegate = context.coordinator
		return view
	}

	func updateNSView(_ uiView: MetalKit.MTKView, context: Context) {}

	// MARK: Coordinator (MetalKit delegate)

	class Coordinator: NSObject, MetalKit.MTKViewDelegate {
		let _draw: Draw
		init(draw: @escaping Draw) { self._draw = draw }

		func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {}

		func draw(in view: MTKView) {
			guard
				let drawable = asserted(view.currentDrawable),
				let renderPassDescriptor = asserted(view.currentRenderPassDescriptor)
			else { return }
			self._draw(drawable, renderPassDescriptor, view.drawableSize)
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
