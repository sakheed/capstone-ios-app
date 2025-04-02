import tensorflow as tf
import coremltools as ct

# Load the pre-trained YAMNet model.
yamnet_model = tf.saved_model.load('yamnet')

# Wrap the model in a tf.keras.Model with an explicit input signature.
class YamnetKerasModel(tf.keras.Model):
    def __init__(self, yamnet):
        super(YamnetKerasModel, self).__init__()
        self.yamnet = yamnet

    @tf.function(input_signature=[tf.TensorSpec(shape=[16000], dtype=tf.float32)])
    def call(self, waveform):
        outputs = self.yamnet(waveform=waveform)
        return {
            "scores": outputs[0],
            "embeddings": outputs[1],
            "spectrogram": outputs[2]
        }


# Create an instance of the wrapped model.
wrapped_model = YamnetKerasModel(yamnet_model)

# Build the model by calling it on a dummy input.
dummy_input = tf.random.uniform([16000], dtype=tf.float32)
_ = wrapped_model(dummy_input)

# Obtain a concrete function from the model.
concrete_func = wrapped_model.call.get_concrete_function(
    tf.TensorSpec([16000], tf.float32)
)

# Save the model as a SavedModel, explicitly passing the concrete function.
saved_model_dir = "saved_yamnet_keras_model"
tf.saved_model.save(wrapped_model, saved_model_dir, signatures={'serving_default': concrete_func})

# Convert the SavedModel to Core ML format.
coreml_model = ct.convert(
    saved_model_dir,
    source="tensorflow",
    inputs=[ct.TensorType(shape=(16000,), name="waveform")],
)

# Save the converted Core ML model.
coreml_model.save("YAMNet.mlmodel")
