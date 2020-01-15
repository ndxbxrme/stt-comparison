module.exports = (sourceSampleRate, targetSampleRate) ->
  bufferUnusedSamples = []
  downsample = (bufferNewSamples) ->
    buffer = null
    newSamples = bufferNewSamples.length
    unusedSamples = bufferUnusedSamples.length
    
    if unusedSamples > 0
      buffer = new Float32Array unusedSamples + newSamples
      i = 0
      while i < unusedSamples
        buffer[i] = bufferUnusedSamples[i]
        i++
      i = 0
      while i < newSamples
        buffer[unusedSamples + i] = bufferNewSamples[i]
    else
      buffer = bufferNewSamples
    filter = [
      -0.037935, -0.00089024, 0.040173, 0.019989, 0.0047792, -0.058675, -0.056487,
      -0.0040653, 0.14527, 0.26927, 0.33913, 0.26927, 0.14527, -0.0040653, -0.056487,
      -0.058675, 0.0047792, 0.019989, 0.040173, -0.00089024, -0.037935
    ]
    samplingRateRatio = sourceSampleRate / targetSampleRate
    nOutputSamples = Math.floor((buffer.length - filter.length) / samplingRateRatio) + 1
    outputBuffer = new Float32Array(nOutputSamples)
    i2 = 0
    while i2 + filter.length - 1 < buffer.length
      offset = Math.round(samplingRateRatio * i2)
      sample = 0
      j = 0
      while j < filter.length
        sample += buffer[offset + j] * filter[j]
        j++
      outputBuffer[i2] = sample
      i2++
    indexSampleAfterLastUsed = Math.round(samplingRateRatio * i2)
    remaining = buffer.length - indexSampleAfterLastUsed
    if remaining > 0
      bufferUnusedSamples = new Float32Array remaining
      i = 0
      while i < remaining
        bufferUnusedSamples[i] = buffer[indexSampleAfterLastUsed + i]
        i++
    else
      bufferUnusedSamples = new Float32Array(0)
    outputBuffer
  floatTo16BitPCM = (input) ->
    output = new DataView new ArrayBuffer(input.length * 2)
    i = 0
    while i < input.length
      multiplier = if input[i] < 0 then 0x8000 else 0x7fff
      output.setInt16(i * 2, (input[i] * multiplier)|0, true)
      i++
    new Buffer output.buffer
    
  downsample: downsample
  floatTo16BitPCM: floatTo16BitPCM