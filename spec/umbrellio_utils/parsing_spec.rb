# frozen_string_literal: true

describe UmbrellioUtils::Parsing do
  describe "#parse_xml" do
    subject(:parsed_data) { described_class.parse_xml(xml, **kwargs) }

    let(:xml) { <<~XML }
      <root some-attr="test">
        <some-tag>some value</some-tag>
        <otherTag>other value &amp;</otherTag>
      </root>
    XML

    let(:kwargs) { {} }

    specify do
      expect(parsed_data).to eq(
        root: { some_tag: "some value", other_tag: "other value &" },
      )
    end

    context "with snakecase = false" do
      let(:kwargs) { Hash[snakecase: false] }

      specify do
        expect(parsed_data).to eq(
          root: { "some-tag": "some value", otherTag: "other value &" },
        )
      end
    end

    context "with remove_attributes = false" do
      let(:kwargs) { Hash[remove_attributes: false] }

      specify do
        expect(parsed_data).to eq(
          root: { "@some_attr": "test", some_tag: "some value", other_tag: "other value &" },
        )
      end
    end
  end
end
