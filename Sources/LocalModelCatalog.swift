import Foundation

struct LocalModelFile: Sendable {
    let path: String
    let size: Int64
    let sha256: String
}

struct LocalModelDescriptor: Sendable {
    let name: String
    let folder: String
    let repository: String
    let revision: String
    let files: [LocalModelFile]
    var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }
}

enum LocalModelCatalog {
    static let parakeet = LocalModelDescriptor(name: "Parakeet v3", folder: "parakeet-tdt-0.6b-v3-coreml",
        repository: "FluidInference/parakeet-tdt-0.6b-v3-coreml", revision: "7dd20fe6b1797d35f5e3307e8b1732d9a178edfe", files: [
            .init(path: "Decoder.mlmodelc/analytics/coremldata.bin", size: 243, sha256: "4238c4e81ecd0dc94bd7dfbb60f7e2cc824107c1ffe0387b8607b72833dba350"),
            .init(path: "Decoder.mlmodelc/coremldata.bin", size: 554, sha256: "18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99"),
            .init(path: "Decoder.mlmodelc/metadata.json", size: 3427, sha256: "a39e93cd8371b8ded92635c7804fcd0590f0d1dd9415c6d19a0484be073077d9"),
            .init(path: "Decoder.mlmodelc/model.mil", size: 13110, sha256: "ef2a0a281695398a62fde86ac269c68f73d5b578d7ed3b31f2ba91a2d1ea1f35"),
            .init(path: "Decoder.mlmodelc/weights/weight.bin", size: 23604992, sha256: "48adf0f0d47c406c8253d4f7fef967436a39da14f5a65e66d5a4b407be355d41"),
            .init(path: "Encoder.mlmodelc/analytics/coremldata.bin", size: 243, sha256: "42e638870d73f26b332918a3496ce36793fbb413a81cbd3d16ba01328637a105"),
            .init(path: "Encoder.mlmodelc/coremldata.bin", size: 485, sha256: "d48034a167a82e88fc3df64f60af963ab3983538271175b8319e7d5720a0fb86"),
            .init(path: "Encoder.mlmodelc/metadata.json", size: 2921, sha256: "da24da9cca943fb29d7fa8e376d57fca7cb3aa08ca51b956b0b0e56813f087e9"),
            .init(path: "Encoder.mlmodelc/model.mil", size: 959769, sha256: "ed7b19156ca29fa7dfd6891deb9fda4b0e8893f68597c985d135736546a43808"),
            .init(path: "Encoder.mlmodelc/weights/weight.bin", size: 445187200, sha256: "e2020f323703477a5b21d7c2d282c403e371afb5962e79877e3033e73ba6f421"),
            .init(path: "JointDecisionv3.mlmodelc/analytics/coremldata.bin", size: 243, sha256: "26def4bf73dd56d29dee21c8ef97cb8969e62f6120ed1adc91e46828e2737b6c"),
            .init(path: "JointDecisionv3.mlmodelc/coremldata.bin", size: 521, sha256: "f5fc08b741400f0088492c9e839418b1e18522f19cba28d361dd030c5f398342"),
            .init(path: "JointDecisionv3.mlmodelc/metadata.json", size: 3453, sha256: "d9307211b9a37e0f0ac260c7660b1571a3de25841035cfdf9b58fd40425f890f"),
            .init(path: "JointDecisionv3.mlmodelc/model.mil", size: 11775, sha256: "be60732943389a047175111a83f8839f3eb39d4803adafa828a0871b2f39818d"),
            .init(path: "JointDecisionv3.mlmodelc/weights/weight.bin", size: 12642764, sha256: "4e0e63d840032f7f07ddb1d64446051166281e5491bf22da8a945c41f6eedb3e"),
            .init(path: "Preprocessor.mlmodelc/analytics/coremldata.bin", size: 243, sha256: "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d"),
            .init(path: "Preprocessor.mlmodelc/coremldata.bin", size: 486, sha256: "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d"),
            .init(path: "Preprocessor.mlmodelc/metadata.json", size: 2841, sha256: "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf"),
            .init(path: "Preprocessor.mlmodelc/model.mil", size: 28181, sha256: "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93"),
            .init(path: "Preprocessor.mlmodelc/weights/weight.bin", size: 491072, sha256: "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea"),
            .init(path: "parakeet_vocab.json", size: 151122, sha256: "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735"),
        ])
    static let qwen = LocalModelDescriptor(name: "Qwen 3.5 4B (4-bit)", folder: "Qwen3.5-4B-4bit",
        repository: "mlx-community/Qwen3.5-4B-4bit", revision: "0e7ffd5c629ef7719d4cbc04069232580bfa9d9c", files: [
            .init(path: "chat_template.jinja", size: 7756, sha256: "a4aee8afcf2e0711942cf848899be66016f8d14a889ff9ede07bca099c28f715"),
            .init(path: "config.json", size: 3366, sha256: "f3efc81b2ea8d96a45301037d3ccccbcccdef44a961845c87f286aaddbc6eaaa"),
            .init(path: "model.safetensors", size: 3034300695, sha256: "5fb9acd0246866381cf8c5c354c6db1019f6498eec4ccb4f5edcc71ffeacb2db"),
            .init(path: "model.safetensors.index.json", size: 101944, sha256: "52e534c41f7b97708329c85f762e5882bf48bd5955a422c6ae74eba321e6048a"),
            .init(path: "tokenizer.json", size: 19989343, sha256: "87a7830d63fcf43bf241c3c5242e96e62dd3fdc29224ca26fed8ea333db72de4"),
            .init(path: "tokenizer_config.json", size: 1139, sha256: "e98f1901ac6f0adff67b1d540bfa0c36ac1a0cf59eb72ed78146ef89aafa1182"),
        ])
}
