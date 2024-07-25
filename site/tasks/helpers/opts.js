'use strict';

exports.swc = () => {
  jsc: {
    target: 'es2022'
  }
}

exports.closureCompiler = () => {
  return {
    compilation_level: 'ADVANCED',
    warning_level: 'VERBOSE',
    language_out: 'ECMASCRIPT_NEXT',
    generate_exports: true,
    export_local_property_definitions: true,
    output_wrapper: '(function(window, document){\n%output%\n})(window, document);',
    js_output_file: 'cardsorter.js',
  };
};

exports.crisper = () => {
  return {
    scriptInHead: false,
  };
};

exports.lightningcss = () => {
  return {
    minify: true,
  };
};

exports.sass = () => {
  return {
    outputStyle: 'expanded',
    precision: 5,
  };
};

exports.terser = () => {
  return {
    compress: {
      drop_console: true,
      keep_infinity: true,
      passes: 5,
    },
    output: {
      beautify: false,
    },
    toplevel: false,
  };
};

exports.vulcanize = () => {
  return {
    excludes: ['prettify.js'], // prettify produces errors when inlined
    inlineCss: true,
    inlineScripts: true,
    stripComments: true,
    stripExcludes: ['iron-shadow-flex-layout.html'],
  };
};

exports.webserver = () => {
  return {
    livereload: false,
    port: 8000,
    host: '0.0.0.0'
  };
};
