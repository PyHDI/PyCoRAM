#ifndef DIJKSTRA_H
#define DIJKSTRA_H

#include <stdio.h>
#include <stdlib.h>
#include <queue>
#include <vector>
#include <list>
#include <map>

typedef unsigned int Uint;
#define MAX_NODES (32 * 1024 * 1024)
#define MAX_PAGES (16 * 1024 * 1024)
#define PAGE_SIZE (8)

using namespace std;

//------------------------------------------------------------------------------
struct Page
{
  Uint num_entries;
  vector< pair<Uint, Uint> > edges;
  Page():
    num_entries(0), edges()
  {
    //    edges.reserve(PAGE_SIZE);
  }
  /*
  ~Page()
  {
  }
  Page(const Page& page):
    num_entries(page.num_entries), edges(page.edges)
  {
  }
  */
  bool isfull()
  {
    return this->num_entries >= PAGE_SIZE;
  }
  void add_edge(Uint dst, Uint cost)
  {
    this->edges.push_back( std::move(pair<Uint, Uint>(dst, cost)) );
  }
};

//------------------------------------------------------------------------------
struct Node
{
  Uint id;
  Node* parent_node;
  Uint current_cost;
  bool visited;
  vector<Page*> pages;
  Node():
    id(0), parent_node(NULL), current_cost(0), visited(false), pages()
  {
    //    pages.reserve(MAX_PAGES);
  }
  Node(const Node& node):
    id(node.id), parent_node(node.parent_node), current_cost(node.current_cost),
    visited(node.visited), pages(node.pages)
  {
  }
  ~Node()
  {
  }
  Node(Uint id):
    id(id), parent_node(NULL), current_cost(0), visited(false), pages()
  {
    //    pages.reserve(MAX_PAGES);
  }
  void add_edge(Uint dst, Uint cost)
  {
    for(auto it=this->pages.begin(); it != this->pages.end(); ++it){
      if(! (*it)->isfull()){
        (*it)->add_edge(dst, cost);
        return;
      }
    }
    this->pages.push_back( new Page() );
    this->pages.back()->add_edge(dst, cost);
  }
  void set_visited()
  {
    this->visited = true;
  }
};

//------------------------------------------------------------------------------
class GreaterCost
{
public:
  bool operator() (pair<Uint,Uint> l, pair<Uint,Uint> r)
  {
    return (l.first > r.first);
  }
};

//------------------------------------------------------------------------------
class Dijkstra
{
private:
  Uint number_of_nodes;
  Uint number_of_edges;
  vector<Node*> node_array;

  priority_queue< pair<Uint, Uint>, vector<pair<Uint, Uint> >, GreaterCost > heap;
  map<Uint, Node*> idtable;

  void add_node(Uint id);
  void push_heap(Uint cost, Uint id);
  void pop_heap(Uint& cost, Uint& id);

public:
  Dijkstra():
    number_of_nodes(0), number_of_edges(0)
  {
    //    node_array.reserve(MAX_NODES);
  }

  void add_edge(Uint src, Uint dst, Uint cost);
  Node* get_node(Uint id);
  void update(Uint cost, Node* node);
  void find_shortest_path(Uint start, Uint goal, Uint& cost, list<Uint>& result);
  void print_result(Uint cost, list<Uint>& result);
};

#endif
