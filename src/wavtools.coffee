
floatTo16BitPCM = (input) ->
  output = new DataView new ArrayBuffer(input.length * 2)
  i = 0
  while i < input.length
    multiplier = if input[i] < 0 then 0x8000 else 0x7fff
    output.setInt16(i * 2, (input[i] * multiplier)|0, true)
    i++
  Buffer.from output.buffer

pcmEncode = (input) ->
  offset = 0
  buffer = new ArrayBuffer(input.length * 2)
  view = new DataView buffer
  i = 0
  while i < input.length
    s = Math.max(-1, Math.min(1, input[i]))
    val = if s < 0 then s * 0x8000 else s * 0x7fff
    view.setInt16 offset, val, true
    offset += 2
    i++
  buffer
  
downsampleBuffer = (buffer, inputSampleRate, outputSampleRate) ->
  return buffer if outputSampleRate is inputSampleRate
  sampleRateRatio = inputSampleRate / outputSampleRate
  newLength = Math.round(buffer.length / sampleRateRatio)
  result = new Float32Array newLength
  offsetResult = 0
  offsetBuffer = 0
  while offsetResult < result.length
    nextOffsetBuffer = Math.round((offsetResult + 1) * sampleRateRatio)
    accum = 0
    count = 0
    i = offsetBuffer
    while i < nextOffsetBuffer && i < buffer.length
      accum += buffer[i]
      count++
      i++
    result[offsetResult] = accum / count
    offsetResult++
    offsetBuffer = nextOffsetBuffer
  result

module.exports =
  floatTo16BitPCM: floatTo16BitPCM
  pcmEncode: pcmEncode
  downsampleBuffer: downsampleBuffer