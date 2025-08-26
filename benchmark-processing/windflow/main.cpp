#include <windflow/windflow.hpp>
#include <windflow/connectors/kafka.hpp>
#include <iostream>
#include <string>
#include <cctype>

using namespace wf;

int main() {
    // Kafka configuration
    std::string brokers = "localhost:9092";
    std::string input_topic = "input-topic";
    std::string output_topic = "output-topic";
    std::string group_id = "windflow-consumer-group";

    // Define pipeline
    wf::Pipeline p;

    // Kafka source: consumes strings
    auto source = wf::kafka::Source<std::string>(brokers, group_id, input_topic);

    // Parallel processing: each message handled independently
    auto process = wf::ParDo<std::string, std::string>(
        [](const std::string& msg, wf::Emitter<std::string>& emit) {
            std::string result = msg;
            for (auto &c : result) c = std::toupper(c);
            emit(result);
        },
        4   // number of parallel workers/threads
    );

    // Kafka sink: produces results
    auto sink = wf::kafka::Sink<std::string>(brokers, output_topic);

    // Build pipeline
    p.add_source(source)
     .add(process)
     .add_sink(sink);

    // Run pipeline
    p.run();

    return 0;
}
