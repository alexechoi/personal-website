// Renders projects.json, which scripts/build-index.sh generates on every deploy.
const list = document.getElementById("projects");

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  Object.assign(node, attrs);
  node.append(...children);
  return node;
}

function render(projects) {
  list.replaceChildren();
  if (projects.length === 0) {
    list.append(el("li", { className: "empty" }, "Nothing here yet."));
    return;
  }
  for (const p of projects) {
    const title = p.url ? el("a", { href: p.url }, p.name) : p.name;
    const meta = el("div", { className: "project-meta" },
      ...p.tags.map((t) => el("span", { className: "tag" }, t)),
      ...(p.source ? [el("a", { href: p.source }, "source")] : []),
    );
    list.append(el("li", { className: "project" },
      el("div", { className: "project-title" }, title),
      ...(p.description ? [el("p", {}, p.description)] : []),
      ...(meta.childElementCount ? [meta] : []),
    ));
  }
}

fetch("projects.json")
  .then((r) => (r.ok ? r.json() : []))
  .then(render)
  .catch(() => render([]));
