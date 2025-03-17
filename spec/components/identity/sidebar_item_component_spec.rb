# frozen_string_literal: true

RSpec.describe Identity::SidebarItemComponent, type: :component do
  context 'with an inactive item' do
    let(:rendered) do
      render_inline(described_class.new(
        path: '/', title: 'Hello', explanation: 'Hello Person', active: false
      ))
    end

    it 'renders the title and explanation' do
      aggregate_failures do
        expect(rendered).to have_text('Hello')
        expect(rendered).to have_text('Hello Person')
      end
    end

    it 'has active item classes' do
      expect(rendered).to have_css('a', class: 'text-midnight-450')
    end
  end

  context 'with an active item' do
    let(:rendered) do
      render_inline(described_class.new(
        path: '/', title: 'Hello', explanation: 'Hello Person', active: true
      ))
    end

    it 'renders the title and explanation' do
      aggregate_failures do
        expect(rendered).to have_text('Hello')
        expect(rendered).to have_text('Hello Person')
      end
    end

    it 'has active item classes' do
      expect(rendered).to have_css('a', class: 'text-midnight-800')
    end
  end
end
