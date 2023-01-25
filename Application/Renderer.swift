//
//  Renderer.swift
//  Metal-SwiftUI
//

import Metal


class Renderer {

	let device: MTLDevice
	let renderPipelineState: MTLRenderPipelineState
	let commandQueue: MTLCommandQueue

	private var _frameIndex = 0

	init?() {
		guard
			let device = asserted(MTLCreateSystemDefaultDevice()),
			let renderPipelineState = asserted({ () -> MTLRenderPipelineState? in
				guard
					let library = asserted(device.makeDefaultLibrary()),
					let vertexFunction = asserted(library.makeFunction(name: "vertex_main")),
					let fragmentFunction = asserted(library.makeFunction(name: "fragment_main"))
				else { return nil }
				let descriptor = MTLRenderPipelineDescriptor()
				descriptor.vertexFunction = vertexFunction
				descriptor.fragmentFunction = fragmentFunction
				descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
				do { return try device.makeRenderPipelineState(descriptor: descriptor) }
				catch { assertionFailure(String(describing: error)); return nil }
			}()),
			let commandQueue = device.makeCommandQueue()
		else { return nil }

		self.device = device
		self.renderPipelineState = renderPipelineState
		self.commandQueue = commandQueue
	}

	func render(
		to drawable: MTLDrawable,
		using renderPassDescriptor: MTLRenderPassDescriptor,
		size drawableSize: CGSize
	) {
		defer { self._frameIndex += 1 }

		guard
			let commandBuffer = asserted(self.commandQueue.makeCommandBuffer()),
			let commandEncoder = asserted( commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor))
		else { return }

		var fragmentUniforms = FragmentUniforms(modifier: Float32(self._frameIndex) * .pi / 60)

		commandEncoder.setRenderPipelineState(self.renderPipelineState)
		commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout.stride(ofValue: fragmentUniforms), index: 0)
		commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
		commandEncoder.endEncoding()

		commandBuffer.present(drawable)
		commandBuffer.commit()
	}
}
